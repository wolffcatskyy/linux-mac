# Running macOS Tahoe on Mac Pro 6,1 via KVM

## Why This Works

Apple dropped macOS support for the Mac Pro 6,1. OpenCore Legacy Patcher (OCLP) extends support by shimming deprecated kexts, but Tahoe support is uncertain and may never be complete.

This project takes a different approach: run macOS Tahoe as a KVM guest on a custom Linux kernel tuned for the 6,1 hardware. The Linux kernel handles the hardware directly with modern drivers, and macOS runs in a high-performance virtual machine.

**Right now (Phase 1):** macOS Tahoe boots and runs with software rendering via QXL/SPICE. CPU-bound tasks run at near-native speed (KVM overhead is 2-5%). The host's amdgpu driver handles display compositing.

**Future (Phase 3):** Full GPU acceleration via open-source PVG host implementation. See [pvg-linux.md](pvg-linux.md) for the roadmap.

## Prerequisites

- Mac Pro 6,1 running Arch Linux with the `linux-macpro61` kernel
- At least 32GB RAM (16GB for host, 16GB for guest)
- 100GB+ free disk space for the macOS disk image
- macOS Tahoe installer (via `macrecovery.py` from OpenCore)
- QEMU 10.0+ (for apple-gfx-pci support in future phases)
- OpenCore bootloader image

## Required Packages

```bash
# Arch Linux
sudo pacman -S qemu-full libvirt virt-manager edk2-ovmf \
    spice-gtk dmidecode

# Enable libvirtd
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

## Phase 1: macOS Tahoe on QXL (Available Now)

### Step 1: Prepare OpenCore Image

Download or build an OpenCore bootloader configured for KVM:

- Target: KVM/QEMU virtual machine
- SMBIOS: `MacPro7,1` (closest supported model for Tahoe)
- SecureBootModel: `Disabled`
- SIP: Disabled for initial setup

Place the OpenCore image at `~/kvm/OpenCore.qcow2`.

### Step 2: Create macOS Disk Image

```bash
mkdir -p ~/kvm
qemu-img create -f qcow2 ~/kvm/macos-tahoe.qcow2 128G
```

### Step 3: Download macOS Recovery

```bash
git clone https://github.com/acidanthera/OpenCorePkg.git
cd OpenCorePkg/Utilities/macrecovery
python3 macrecovery.py -b Mac-27AD2F918AE68F61 download
```

### Step 4: QEMU Launch Script

```bash
#!/bin/bash
# launch-macos.sh — macOS Tahoe on Mac Pro 6,1 via KVM

QEMU=qemu-system-x86_64
OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.fd"
OVMF_VARS="$HOME/kvm/OVMF_VARS.fd"

# Copy OVMF vars if first run
[ -f "$OVMF_VARS" ] || cp /usr/share/edk2/x64/OVMF_VARS.fd "$OVMF_VARS"

$QEMU \
    -name "macOS-Tahoe" \
    -machine q35,accel=kvm,kernel-irqchip=on \
    -cpu host,vendor=GenuineIntel,+invtsc,+hypervisor,kvm=on \
    -smp cores=8,threads=2,sockets=1 \
    -m 16G \
    \
    -device ich9-intel-hda -device hda-duplex \
    -device qemu-xhci,id=xhci \
    -device usb-kbd -device usb-tablet \
    \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    \
    -drive id=OpenCore,if=none,format=qcow2,file="$HOME/kvm/OpenCore.qcow2" \
    -device ide-hd,bus=sata.0,drive=OpenCore,bootindex=1 \
    \
    -drive id=InstallMedia,if=none,format=raw,file="$HOME/kvm/BaseSystem.dmg" \
    -device ide-hd,bus=sata.1,drive=InstallMedia \
    \
    -drive id=MacHDD,if=none,format=qcow2,file="$HOME/kvm/macos-tahoe.qcow2" \
    -device ide-hd,bus=sata.2,drive=MacHDD \
    \
    -netdev user,id=net0 \
    -device vmxnet3,netdev=net0 \
    \
    -vga qxl \
    -spice port=5930,disable-ticketing=on \
    -device virtio-serial-pci \
    -chardev spicevmc,id=spicechannel0,name=vdagent \
    -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
    \
    -monitor stdio
```

Connect with: `remote-viewer spice://localhost:5930`

### Step 5: Install macOS

1. Run the launch script
2. Connect via SPICE viewer
3. OpenCore picker → select recovery/installer
4. Disk Utility → format 128GB drive as APFS
5. Install macOS Tahoe
6. Reboot → OpenCore boots from installed drive
7. Complete setup

### Step 6: Post-Install Optimization

After installation, remove the install media line and tune:

```bash
# Match your CPU (e.g., 12-core E5-2697 v2, keep 2 for host)
-smp cores=10,threads=2,sockets=1

# With 64GB host RAM, give guest half
-m 32G

# Better disk I/O with virtio (requires virtio kext via OpenCore)
-device virtio-blk-pci,drive=MacHDD
```

## Network Options

```bash
# Bridge (best for LAN access)
-netdev bridge,id=net0,br=br0 \
-device vmxnet3,netdev=net0

# TAP (maximum performance)
-netdev tap,id=net0,ifname=tap0,script=no,downscript=no \
-device virtio-net-pci,netdev=net0
```

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
| Disk (virtio) | 80-90% | Requires virtio kext |
| Disk (IDE) | 50-70% | Emulation overhead |
| 2D desktop | Usable | Software rendered via QXL |
| 3D / Metal | Not available | Phase 3 |
| Video playback | Good | CPU-decoded |
| Web browsing | Good | Mostly CPU-bound |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| macOS doesn't boot | Check OpenCore config, ensure Tahoe-compatible SMBIOS |
| No display | Verify SPICE connection, try `-vnc :0` fallback |
| Kernel panic at install | Reduce CPU count, disable HT |
| No network | Try `e1000-82545em` instead of `vmxnet3` |
| Poor performance | Verify KVM: `dmesg \| grep kvm` |

## What's Next

See [pvg-linux.md](pvg-linux.md) for the GPU acceleration roadmap — Phase 3 brings full Metal support and "faster than bare metal OCLP" performance.
