# Pre-configured ISOs for Mac Pro 6,1

## Overview

Two ready-to-install ISOs specifically for the Mac Pro 6,1, each including the custom kernel, Mesa 26.1-dev with RADV Vulkan, and macOS Tahoe KVM one-click setup.

| ISO | Base | Desktop | Installer | Target |
|-----|------|---------|-----------|--------|
| **AnduinOS** | Ubuntu LTS | GNOME (Windows-like UX) | Calamares | Stability and familiarity |
| **AerynOS** | Serpent OS | COSMIC/GNOME | Lichen (TUI) | Modern, performance-focused |

Both share the same custom kernel and GPU stack. The difference is the userland.

## What's Included

These are fully configured, opinionated systems. Everything is pre-configured and working out of the box.

Every ISO ships with:

- **Desktop environment** — GNOME (AnduinOS) or COSMIC (AerynOS), fully configured
- **Custom kernel** (`linux-macpro61`) — amdgpu=m, SI support, KVM, no gmux, Ivy Bridge optimized
- **Mesa 26.1-dev** with RADV Vulkan — latest GCN 1.0 fixes, full GPU acceleration
- **macOS Tahoe KVM** — desktop icon, one-click setup, auto-downloads recovery directly from Apple
- **OpenCore.qcow2** — pre-configured for macOS Tahoe on Ivy Bridge-EP KVM
- **Fan control** — macfanctld with Mac Pro 6,1 curve profiles
- **Sysctl tuning** — kvm.ignore_msrs, network, memory optimizations
- **Boot entries** — pre-configured for Mac Pro 6,1 EFI
- **No configuration required** — boot USB, install, done

What's NOT shipped (for legal reasons):

- **macOS recovery image** — downloads automatically from Apple's servers (`osrecovery.apple.com`) when you click the desktop icon. ~700MB, ~5 minutes. We automate the download, we don't redistribute it.

## Build

### AnduinOS (Ubuntu-based)

```bash
# Requires: AMD64 Linux host, debootstrap, live-build, squashfs-tools
cd image/anduinos
sudo ./build.sh
# Output: dist/linux-mac-anduinos-*.iso
```

**How it works:**
1. Clones AnduinOS build system (Ubuntu LTS + GNOME + Calamares)
2. Injects custom kernel package (.deb built from our config)
3. Adds Mesa 26.1-dev packages
4. Copies macOS Tahoe KVM toolkit to /opt/macos-tahoe-kvm/
5. Installs desktop launcher (first-boot systemd oneshot)
6. Adds sysctl tuning and fan control
7. Builds bootable ISO with Calamares installer

### AerynOS (Serpent OS-based)

```bash
# Requires: moss, boulder (AerynOS build tools)
cd image/aerynos
sudo ./build.sh
# Output: dist/linux-mac-aerynos-*.iso
```

**How it works:**
1. Uses AerynOS img-tests ISO construction scripts
2. Builds custom kernel and mesa as stone packages via boulder
3. Includes macOS Tahoe KVM toolkit
4. Builds bootable ISO with lichen installer

**Note:** AerynOS tooling is still early-stage (alpha). The AnduinOS ISO is more mature and recommended for initial release.

## Directory Structure

```
image/
├── README.md              # This file
├── common/                # Shared between both ISOs
│   ├── overlay/           # Filesystem overlay (sysctl, scripts, etc.)
│   │   ├── etc/
│   │   │   └── sysctl.d/
│   │   │       └── 99-macpro.conf
│   │   ├── opt/
│   │   │   └── macos-tahoe-kvm/  → symlink to ../../macos-tahoe-kvm/
│   │   └── usr/
│   │       └── share/
│   │           └── applications/
│   │               └── macos-tahoe-kvm.desktop
│   └── packages-common.txt
├── anduinos/
│   ├── build.sh           # AnduinOS ISO build script
│   ├── packages.txt       # Ubuntu packages to add
│   └── hooks/             # Calamares post-install hooks
└── aerynos/
    ├── build.sh           # AerynOS ISO build script
    ├── stone.yaml         # Custom kernel recipe for boulder
    └── packages.txt       # AerynOS packages to add
```

## Build Dependencies

### AnduinOS build host
```
debootstrap live-build squashfs-tools xorriso mtools grub-efi-amd64-bin
```

### AerynOS build host
```
moss boulder (from AerynOS os-tools)
```

## Release Workflow

1. Build custom kernel: `cd packaging/arch && makepkg -s`
2. Build AnduinOS ISO: `cd image/anduinos && sudo ./build.sh`
3. Test in QEMU: `qemu-system-x86_64 -cdrom dist/*.iso -m 4G`
4. Write to USB: `dd if=dist/*.iso of=/dev/sdX bs=4M status=progress`
5. Boot Mac Pro 6,1 from USB
6. Install via Calamares
7. Reboot (full poweroff, NOT warm reboot!)
