# macOS Tahoe KVM — ISO Integration Guide

## Overview

This toolkit adds a **desktop icon** to your custom Linux ISO that lets customers
download and run macOS Tahoe in a pre-configured KVM virtual machine. The Mac Pro 6,1
hardware is auto-detected and the VM is tuned accordingly.

**What's automated:** dependency check, hardware detection, macOS recovery download
from Apple, virtual disk creation, QEMU config generation, VM launch.

**What's manual:** the macOS installer GUI itself (disk selection, account creation,
Apple ID).

## Files

```
macos-tahoe-kvm/
├── scripts/
│   ├── macos-tahoe-setup.sh          # Main setup + download + configure
│   ├── install-desktop-launcher.sh   # First-boot: creates desktop icon
│   ├── find-iommu-groups.sh          # (generated) IOMMU group lister
│   └── bind-vfio.sh                  # (generated) GPU passthrough helper
├── opencore-efi/
│   └── OpenCore.qcow2               # ← YOU MUST PROVIDE THIS
├── vm/                               # (created at runtime)
│   ├── ovmf/                         # UEFI firmware (auto-downloaded)
│   ├── recovery/                     # macOS recovery (auto-downloaded)
│   └── macOS-Tahoe.qcow2            # Virtual disk (auto-created)
├── launch-macos-tahoe.sh            # (generated) QEMU launch script
└── ISO-INTEGRATION.md               # This file
```

## Integration Steps

### 1. Prepare OpenCore EFI

You need an OpenCore EFI image configured for macOS Tahoe on Ivy Bridge-EP.
Options:

- **Use ultimate-macOS-KVM's OpenCore assistant** to generate one
- **Build from OpenCorePkg releases:** https://github.com/acidanthera/OpenCorePkg/releases
- **Key config.plist settings for Mac Pro 6,1:**
  - SMBIOS: `MacPro6,1`
  - SecureBootModel: `Disabled` (for KVM)
  - SIP: can leave enabled
  - Boot args: `-v keepsyms=1` (for debug, remove for production)

> **CRITICAL: CryptexFixup.kext is REQUIRED for macOS Tahoe to boot in KVM.**
> Without this kext, macOS Tahoe will fail to boot in any virtual machine.
> Download from: https://github.com/acidanthera/CryptexFixup/releases
> Add to `EFI/OC/Kexts/CryptexFixup.kext` and enable in `config.plist` under
> `Kernel -> Add`. Recommended boot args: `keepsyms=1 -no_compat_check revpatch=sbvmm,asset`

Place the image at `opencore-efi/OpenCore.qcow2`.

### 2. Add to your ISO build

```bash
# In your ISO build script:
cp -r macos-tahoe-kvm/ ${ISO_ROOT}/opt/macos-tahoe-kvm/
chmod +x ${ISO_ROOT}/opt/macos-tahoe-kvm/scripts/*.sh
```

### 3. First-boot hook

**Option A: Systemd service (recommended)**

```bash
# In your ISO's post-install or first-boot script:
/opt/macos-tahoe-kvm/scripts/install-desktop-launcher.sh --systemd
```

This creates a oneshot systemd service that runs once, creates the desktop
icon for all users, then disables itself.

**Option B: Systemd + prefetch**

```bash
/opt/macos-tahoe-kvm/scripts/install-desktop-launcher.sh --systemd --prefetch
```

Same as above, but also starts downloading the macOS recovery image in the
background on first boot. The download (~700MB) runs silently; when the user
clicks the icon, if it's already done, setup skips straight to VM config.

**Option C: rc.local / autostart**

```bash
# In /etc/rc.local or equivalent:
/opt/macos-tahoe-kvm/scripts/install-desktop-launcher.sh
```

### 4. Dependencies

Ensure your ISO includes these packages:

```
qemu-system-x86 qemu-utils python3 wget curl openssl
```

For GPU passthrough, also include:
```
linux-headers-$(uname -r)   # for vfio modules
```

Your kernel cmdline should include (for passthrough support):
```
intel_iommu=on iommu=pt
```

## Customer Flow

1. Boot your Linux ISO on Mac Pro 6,1
2. Desktop shows "macOS Tahoe KVM" icon
3. Click icon → terminal opens with setup wizard
4. Setup auto-detects hardware (CPU cores, RAM, GPUs)
5. Downloads macOS Tahoe recovery from Apple (~700MB, ~5min)
6. Creates pre-configured VM (disk, QEMU args, network)
7. Launches VM → macOS installer appears
8. Customer walks through macOS install (15-30min)
9. After install, delete recovery image, re-launch with `./launch-macos-tahoe.sh`

## GPU Passthrough (Optional)

For customers who want native GPU acceleration in the macOS VM:

```bash
# 1. Find the FirePro GPU PCI addresses
sudo /opt/macos-tahoe-kvm/scripts/find-iommu-groups.sh

# 2. Bind GPUs to vfio-pci
sudo /opt/macos-tahoe-kvm/scripts/bind-vfio.sh 03:00.0 03:00.1

# 3. Edit launch script — uncomment GPU_PASSTHROUGH_ARGS
#    and fill in the PCI addresses
nano /opt/macos-tahoe-kvm/launch-macos-tahoe.sh

# 4. Launch
./launch-macos-tahoe.sh
```

**Note:** GPU passthrough means the host Linux loses display output on that GPU.
On the Mac Pro 6,1 with dual FirePros, you can pass one to macOS and keep one
for the host.

## Customisation

Edit the `VM_*` variables at the top of `scripts/macos-tahoe-setup.sh`:

| Variable | Default | Notes |
|----------|---------|-------|
| `VM_RAM` | auto-detected (75% of total) | Capped at 48G |
| `VM_CPU_CORES` | auto-detected (total - 2) | Leave 2 for host |
| `VM_CPU_MODEL` | `Haswell-noTSX` | Works on Ivy Bridge-EP via KVM |
| `VM_DISK_SIZE` | `128G` | qcow2 sparse, real usage ~50-60G |
| `VM_NET_DEVICE` | `vmxnet3` | Use `e1000-82545em` if network issues |
| `BOARD_ID` | Mac Pro 6,1 board ID | For macrecovery download |

## Troubleshooting

**"KVM not available"** — Enable VT-x in firmware: reboot, hold Option,
enter Startup Manager, then boot to firmware settings.

**Recovery download fails** — Check internet connectivity. The download
uses Apple's `osrecovery.apple.com` servers. Try `--download-only` flag
to retry without launching.

**No IOMMU groups** — Ensure `intel_iommu=on iommu=pt` is in your kernel
cmdline. On the Mac Pro 6,1, IOMMU is supported but must be enabled.

**macOS installer doesn't see disk** — Format the virtual disk in Disk Utility
first (APFS for Tahoe). The 128G qcow2 will appear as a physical disk.
