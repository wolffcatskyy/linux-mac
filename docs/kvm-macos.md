# Running macOS Tahoe on Mac Pro 6,1 via KVM

## Why This Works

Apple dropped macOS support for the Mac Pro 6,1. OpenCore Legacy Patcher (OCLP) extends support by shimming deprecated kexts, but Tahoe support is uncertain and may never be complete.

This project takes a different approach: run macOS Tahoe as a KVM guest on a custom Linux kernel tuned for the 6,1 hardware. The Linux kernel handles the hardware directly with modern drivers, and macOS runs in a high-performance virtual machine.

**Right now (Phase 1):** macOS Tahoe boots and runs with software rendering via QXL. CPU-bound tasks run at near-native speed (KVM overhead is 2-5%). The host's amdgpu driver handles display compositing.

**Future (Phase 3):** Full GPU acceleration via open-source PVG host implementation. See [pvg-linux.md](pvg-linux.md) for the roadmap.

## Prerequisites

- Any Linux distribution with KVM support (kernel 5.10+)
- Hardware virtualization enabled in firmware (Intel VT-x or AMD-V)
- At least 32GB RAM (16GB for host, 16GB for guest)
- 100GB+ free disk space for the macOS disk image
- QEMU 8.0+ with KVM support
- The [OSX-KVM](https://github.com/kholia/OSX-KVM) project (provides OpenCore image, OVMF firmware, and recovery download tools)
- `dmg2img` package for converting recovery images

Using the custom `linux-macpro61` kernel from this project is optional but recommended -- it includes built-in firmware, KVM tuning, and sysctl defaults that improve macOS guest performance.

## Required Packages

### Arch Linux

```bash
sudo pacman -S qemu-full libvirt virt-manager edk2-ovmf \
    spice-gtk dmidecode dnsmasq bridge-utils dmg2img
```

### Debian / Ubuntu

```bash
sudo apt install qemu-system-x86 libvirt-daemon-system \
    virt-manager ovmf spice-client-gtk dmidecode \
    dnsmasq-base bridge-utils dmg2img
```

### Fedora

```bash
sudo dnf install @virtualization edk2-ovmf spice-gtk3 \
    dmidecode dnsmasq bridge-utils dmg2img
```

## System Setup

After installing packages, enable the libvirt daemon and add your user to the required groups:

```bash
# Enable libvirtd
sudo systemctl enable --now libvirtd

# Add user to kvm and libvirt groups
sudo usermod -aG kvm,libvirt $USER

# Log out and back in for group changes to take effect
```

Verify KVM is available:

```bash
# Should return 0 (success)
ls /dev/kvm

# Check QEMU can use KVM
qemu-system-x86_64 -accel help | grep kvm
```

### CRITICAL: Enable ignore_msrs

macOS accesses Model-Specific Registers (MSRs) that KVM does not emulate. Without `ignore_msrs=1`, the guest will kernel panic on boot.

**Set at runtime (immediate, lost on reboot):**

```bash
echo 1 > /sys/module/kvm/parameters/ignore_msrs
```

**Set persistently (survives reboot):**

```bash
# Create or edit /etc/modprobe.d/kvm.conf
echo "options kvm ignore_msrs=1 report_ignored_msrs=0" | sudo tee /etc/modprobe.d/kvm.conf

# Reload (or reboot)
sudo modprobe -r kvm_intel && sudo modprobe kvm_intel
# OR on AMD:
# sudo modprobe -r kvm_amd && sudo modprobe kvm_amd
```

`report_ignored_msrs=0` suppresses kernel log spam from the ignored MSR accesses. Without it, dmesg fills with thousands of warnings.

## Phase 1: macOS Tahoe on QXL (Working)

### Step 1: Clone OSX-KVM

Do NOT try to hand-build an OpenCore configuration from scratch. The OSX-KVM project provides a pre-built `OpenCore.qcow2` that handles Apple SMC emulation, SMBIOS spoofing, and all the kext/driver configuration needed for a KVM guest.

```bash
cd ~
git clone --depth 1 https://github.com/kholia/OSX-KVM.git
cd OSX-KVM
```

The key files you get from OSX-KVM:

| File | Purpose |
|------|---------|
| `OpenCore/OpenCore.qcow2` | Pre-built OpenCore bootloader image (handles SMC, SMBIOS, etc.) |
| `OVMF_CODE_4M.fd` | UEFI firmware (code, read-only) |
| `OVMF_VARS-1920x1080.fd` | UEFI firmware variables (includes resolution setting) |
| `fetch-macOS-v2.py` | Downloads macOS recovery images from Apple CDN |

### Step 2: Download macOS Tahoe Recovery

Use the OSX-KVM download script -- not `macrecovery.py` from OpenCorePkg.

```bash
cd ~/OSX-KVM
python3 fetch-macOS-v2.py -s tahoe
```

This downloads `BaseSystem.dmg` from Apple's CDN. Convert it to a raw image that QEMU can use:

```bash
dmg2img -i BaseSystem.dmg BaseSystem.img
```

### Step 3: Create macOS Disk Image

```bash
qemu-img create -f qcow2 ~/OSX-KVM/mac_hdd_ng.img 128G
```

### Step 4: QEMU Launch Command

This is the working command line. Every flag here was tested and verified on a Mac Pro 6,1 (dual Xeon E5-2697 v2).

```bash
qemu-system-x86_64 \
    -name "macOS-Tahoe" \
    -machine q35,accel=kvm,kernel-irqchip=on \
    -cpu host,vendor=GenuineIntel,+invtsc,+hypervisor,kvm=on \
    -smp cores=6,threads=1,sockets=1 \
    -m 16G \
    -device ich9-intel-hda -device hda-duplex \
    -device qemu-xhci,id=xhci \
    -device usb-kbd -device usb-tablet \
    -drive if=pflash,format=raw,readonly=on,file=OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file=OVMF_VARS-1920x1080.fd \
    -device ich9-ahci,id=sata \
    -drive id=OpenCore,if=none,snapshot=on,format=qcow2,file=OpenCore/OpenCore.qcow2 \
    -device ide-hd,bus=sata.0,drive=OpenCore,bootindex=1 \
    -drive id=InstallMedia,if=none,format=raw,file=BaseSystem.img \
    -device ide-hd,bus=sata.1,drive=InstallMedia \
    -drive id=MacHDD,if=none,format=qcow2,file=mac_hdd_ng.img \
    -device ide-hd,bus=sata.2,drive=MacHDD \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device vmxnet3,netdev=net0 \
    -vga qxl \
    -display gtk,show-cursor=on \
    -device virtio-serial-pci \
    -monitor stdio
```

Run this from the `~/OSX-KVM` directory (all file paths are relative to it).

**Key decisions explained:**

| Flag | Why |
|------|-----|
| `-cpu host,...` | Passes through real CPU features natively. No emulation warnings, no traps. See "CPU Model" below. |
| `snapshot=on` on OpenCore | Writes go to a temporary overlay, keeping the OpenCore image clean. Changes are discarded on shutdown. |
| `-vga qxl` | QXL works reliably with macOS. vmware-svga and virtio-vga do not. |
| `-device vmxnet3` | macOS has a native vmxnet3 driver. virtio-net-pci requires extra kexts. |
| `-display gtk` | For local display. Replace with SPICE for remote access (see below). |
| `BaseSystem.img` | The converted recovery image. Must be `.img` (raw), not `.dmg`. |
| `hostfwd=tcp::2222-:22` | SSH into guest via `ssh -p 2222 localhost` after enabling Remote Login in macOS. |

### CPU Model: Why `-cpu host`

Do NOT use `Penryn` or `Skylake-Client` CPU models. These are commonly recommended in older Hackintosh guides but cause problems:

- **Penryn** is a 2008 CPU model. QEMU has to emulate missing instructions, which triggers warnings and can cause instability.
- **Skylake-Client** exposes features your physical CPU may not have, leading to illegal instruction traps.

`-cpu host` passes through whatever the real CPU supports. On the Mac Pro 6,1 (Ivy Bridge EP / Xeon E5 v2), this gives macOS the exact feature set the hardware provides. The additional flags:

- `vendor=GenuineIntel` -- macOS checks for this
- `+invtsc` -- invariant TSC, required for stable timekeeping
- `+hypervisor` -- tells macOS it is running virtualized
- `kvm=on` -- enables KVM paravirtualization

### Apple SMC Emulation

The OSX-KVM `OpenCore.qcow2` handles Apple SMC emulation internally. If you use their boot script (`OpenCore-Boot.sh`), it also includes the QEMU device flag:

```
-device isa-applesmc,osk="..."
```

You do not need to configure this separately when using OSX-KVM's pre-built image.

### Step 5: Install macOS

1. Run the QEMU command from the OSX-KVM directory
2. A GTK window opens (or connect via SPICE if using remote display)
3. OpenCore picker appears -- select the recovery/installer entry
4. Disk Utility -- format the 128GB virtual drive as APFS (GUID partition scheme)
5. Install macOS Tahoe (downloads remaining files from Apple CDN; requires internet)
6. Reboot -- OpenCore boots from installed drive
7. Complete first-run setup

### Step 6: Post-Install Optimization

After installation, remove the InstallMedia lines from the QEMU command (the `-drive id=InstallMedia` and `-device ide-hd,bus=sata.1,drive=InstallMedia` lines).

Tune resources for your hardware:

```bash
# Match your CPU (e.g., 12-core E5-2697 v2, keep some for host)
-smp cores=10,threads=1,sockets=1

# With 64GB host RAM, give guest more
-m 32G
```

### Remote Display (SPICE)

To access the VM remotely instead of using a local GTK window, replace the display lines:

```bash
# Remove:
#   -display gtk,show-cursor=on

# Add:
    -spice port=5930,disable-ticketing=on \
    -chardev spicevmc,id=spicechannel0,name=vdagent \
    -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
```

Connect with: `remote-viewer spice://localhost:5930`

## Network Options

```bash
# User-mode NAT with SSH forwarding (default, simplest)
-netdev user,id=net0,hostfwd=tcp::2222-:22 \
-device vmxnet3,netdev=net0

# Bridge (best for LAN access, guest gets its own IP)
-netdev bridge,id=net0,br=br0 \
-device vmxnet3,netdev=net0

# TAP (maximum performance)
-netdev tap,id=net0,ifname=tap0,script=no,downscript=no \
-device vmxnet3,netdev=net0
```

Always use `vmxnet3` for the network device. macOS includes a native driver for it. `virtio-net-pci` requires installing extra kexts into OpenCore and is not worth the hassle.

## USB Passthrough

```bash
# Specific device (find with lsusb)
-device usb-host,vendorid=0x05ac,productid=0x024f

# Entire USB port
-device usb-host,hostbus=1,hostport=2
```

## Performance Expectations (Phase 1)

| Workload | vs Bare Metal | Notes |
|----------|--------------|-------|
| CPU-bound | 95-98% | KVM is near-native |
| Memory | 95-98% | Direct mapping with hugepages |
| Disk (IDE emulation) | 50-70% | Default; sufficient for most use |
| 2D desktop | Usable | Software rendered via QXL |
| 3D / Metal | Not available | Phase 3 |
| Video playback | Good | CPU-decoded |
| Web browsing | Good | Mostly CPU-bound |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Kernel panic on boot (MSR related) | Set `ignore_msrs=1` -- see System Setup section above. This is the most common cause. |
| macOS doesn't boot past Apple logo | Verify you are using OSX-KVM's `OpenCore.qcow2`, not a hand-built config |
| "CPU emulation warning" in QEMU output | You are using `Penryn` or `Skylake-Client`. Switch to `-cpu host` |
| No display / black screen | Use `-vga qxl`. Do NOT use `vmware-svga` or `virtio-vga` |
| No display with SPICE | Check SPICE port is correct, try `-display gtk` first to rule out display issues |
| Kernel panic: "unable to find driver for this platform" | OpenCore SMBIOS not configured for KVM. Use OSX-KVM's pre-built image. |
| No network in guest | Verify you are using `vmxnet3`, not `virtio-net-pci`. Try `e1000-82545em` as fallback. |
| Poor performance | Verify KVM is active: `dmesg \| grep kvm`. Check `-accel kvm` is in command line. |
| `/dev/kvm` missing | Enable VT-x/AMD-V in BIOS/UEFI firmware |
| Permission denied on `/dev/kvm` | Add user to `kvm` group: `sudo usermod -aG kvm $USER` |
| OpenCore changes don't persist | This is intentional -- `snapshot=on` discards writes. Remove `snapshot=on` if you need to modify the OpenCore image. |
| Recovery can't download macOS | Guest needs internet. Verify NAT networking works (try `ping` in Terminal from recovery). |
| BaseSystem.dmg doesn't work as drive | Convert it first: `dmg2img -i BaseSystem.dmg BaseSystem.img`. QEMU needs a raw image. |

## What NOT to Do (Mistakes We Made)

These are the dead ends we hit before arriving at the working configuration:

1. **Don't hand-build OpenCore from Sample.plist.** The OpenCorePkg `Sample.plist` is a reference file with hundreds of options. Getting it right for a KVM guest requires setting dozens of quirks, kexts, and SMBIOS values correctly. OSX-KVM's pre-built `OpenCore.qcow2` already has all of this done.

2. **Don't use Penryn or Skylake-Client CPU models.** Penryn triggers emulation warnings and is missing modern instruction sets. Skylake-Client can expose features your physical CPU lacks. `-cpu host` passes through the real CPU's feature set and just works.

3. **Don't use virtio-vga or vmware-svga.** Neither works reliably with macOS guests. QXL is the correct choice for Phase 1.

4. **Don't embed BaseSystem.dmg inside the OpenCore ESP.** Some guides suggest copying the recovery image into the OpenCore EFI partition. This is fragile and unnecessary. Mount it as a separate SATA drive (`bus=sata.1`).

5. **Don't forget `ignore_msrs=1`.** Without this kernel parameter, macOS will kernel panic every time. It is not optional.

6. **Don't skip `dmg2img` conversion.** QEMU cannot directly use `.dmg` files as drive images. Always convert to raw `.img` first.

## What's Next

See [pvg-linux.md](pvg-linux.md) for the GPU acceleration roadmap -- what's known, what's a black box, and realistic next steps.
