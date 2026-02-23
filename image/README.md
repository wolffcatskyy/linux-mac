# Pre-configured ISO for Mac Pro 6,1

## Overview

A ready-to-install ISO specifically for the Mac Pro 6,1, including the custom kernel, Mesa 26.1-dev with RADV Vulkan, and macOS Tahoe KVM one-click setup.

| ISO | Base | Desktop | Installer | Target |
|-----|------|---------|-----------|--------|
| **AnduinOS** | Ubuntu LTS | GNOME (Windows-like UX) | Calamares | Stability and familiarity |

## What's Included

A fully configured, opinionated system. Everything is pre-configured and working out of the box.

The ISO ships with:

- **Desktop environment** — GNOME, fully configured
- **Custom kernel** (`linux-macpro61`) — amdgpu=m, SI support, KVM, no gmux, Ivy Bridge optimized
- **Mesa 26.1-dev** with RADV Vulkan — latest GCN 1.0 fixes, full GPU acceleration
- **macOS Tahoe KVM** — desktop icon, one-click setup, auto-downloads recovery directly from Apple
- **OpenCore.qcow2** — pre-configured for macOS Tahoe on Ivy Bridge-EP KVM
- **Fan control** — macfanctld with Mac Pro 6,1 curve profiles
- **Sysctl tuning** — kvm.ignore_msrs, network, memory optimizations
- **Boot entries** — pre-configured for Mac Pro 6,1 EFI
- **No configuration required** — boot USB, install, done

The macOS recovery image (~700MB) downloads directly from Apple's servers when you click the desktop icon. The one-click setup handles everything automatically.

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
```

## Build Dependencies

### AnduinOS build host
```
debootstrap live-build squashfs-tools xorriso mtools grub-efi-amd64-bin
```

## Release Workflow

1. Build custom kernel: `cd packaging/arch && makepkg -s`
2. Build AnduinOS ISO: `cd image/anduinos && sudo ./build.sh`
3. Test in QEMU: `qemu-system-x86_64 -cdrom dist/*.iso -m 4G`
4. Write to USB: `dd if=dist/*.iso of=/dev/sdX bs=4M status=progress`
5. Boot Mac Pro 6,1 from USB
6. Install via Calamares
7. Reboot (full poweroff, NOT warm reboot!)
