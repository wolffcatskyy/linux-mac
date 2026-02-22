# Prebuilt Distro Image

## Decision

Ship a bootable disk image that includes the custom kernel, all distro glue, and KVM tooling pre-configured. Users should be able to write the image to a drive, boot, and have a working Mac Pro 6,1 Linux environment with macOS KVM ready to go.

## Why

The custom kernel is only half the story. Getting macOS KVM working also requires:

- QEMU, libvirt, virt-manager installed and configured
- User in `kvm` and `libvirt` groups
- libvirtd enabled
- dnsmasq and bridge-utils for VM networking
- OVMF firmware for UEFI boot
- SPICE client for display
- sysctl tuning (`kvm.ignore_msrs`, network, memory)
- Fan control (macfanctld)

Documenting all of this per-distro is fragile. A prebuilt image ensures it works out of the box.

## Planned Structure

```
image/
  README.md          # This file
  build.sh           # Build script (produces bootable image)
  packages.txt       # Package list for the image
  overlay/           # Files overlaid onto the image filesystem
    etc/
      sysctl.d/
        99-macpro.conf
      systemd/
        system/
          ...        # Service enablement
    usr/
      local/
        bin/
          launch-macos.sh
```

## Build Script

`build.sh` will:

1. Bootstrap a minimal Arch Linux rootfs
2. Install packages from `packages.txt`
3. Install the custom `linux-macpro61` kernel
4. Apply overlay files (sysctl, services, scripts)
5. Configure user groups, systemd services
6. Produce a raw disk image (convertible to qcow2, ISO, etc.)

## Scope

The image handles **distro glue only** — everything needed beyond the kernel to make the system usable. The kernel itself is built separately via `packaging/arch/PKGBUILD`.

What's in the image:
- Base system (Arch Linux minimal)
- Custom kernel package
- KVM/QEMU stack
- Mesa GPU drivers
- Network and display tooling
- Fan control
- Sysctl tuning

What's NOT in the image:
- Desktop environment (user's choice)
- macOS installer media (legal reasons)
- OpenCore image (user must provide)
