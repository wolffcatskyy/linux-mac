# linux-mac

Custom Linux kernel for the Mac Pro 6,1 (Late 2013). Built-in drivers, embedded GPU firmware, hardware-optimized — boots to desktop with no initramfs required.

## What This Is

A kernel config and PKGBUILD for Linux 7.0 that targets Mac Pro 6,1 hardware specifically. Instead of loading hundreds of modules for hardware you don't have, this kernel builds in exactly what the Mac Pro needs:

- **All GPU variants supported** — D300 (Pitcairn), D500 (Tahiti), D700 (Tahiti XT), firmware embedded in kernel
- **12 modules vs 115+ stock**, ~15s userspace boot vs 36s+
- **Compiler-optimized** — `-march=ivybridge -O3`, 1000Hz tick, full preemption
- **KVM built-in** — run macOS Tahoe in QEMU without OCLP or legacy kext shims
- **NVMe + TRIM** — aftermarket NVMe drives work out of the box

## Hardware Support

| Feature | Status | Notes |
|---------|--------|-------|
| GPU (D300/D500/D700) | Working | amdgpu built-in with firmware, radeonsi/RADV via Mesa |
| Display (DP/HDMI) | Working | Via amdgpu + DC |
| Display (Thunderbolt) | Partial | Works with log spam |
| Vulkan | Working | Via Mesa RADV |
| OpenGL | Working | Via Mesa radeonsi |
| GPU Compute | Limited | OpenCL via Mesa rusticl only — no ROCm for Southern Islands |
| Ethernet | Working | Both ports via tg3 |
| Wi-Fi | Proprietary driver | `broadcom-wl-dkms` (AUR) + `linux-macpro61-headers` |
| Audio (3.5mm) | Working | Intel HDA + Cirrus Logic CS4206 |
| Audio (HDMI/DP) | Working | Via amdgpu |
| USB 3.0 | Working | Fresco Logic FL1100 via xHCI |
| Thunderbolt 2 | Partial | Hotplug log spam |
| NVMe + TRIM | Working | Built-in; enable `fstrim.timer` |
| Bluetooth | Working | Broadcom via btusb |
| KVM | Working | macOS Tahoe virtualization |
| Temperature / Fans | Working | Via applesmc + hwmon; install `macfanctld` (AUR) for fan curves |
| Sleep/Wake | Disabled | Unreliable on this hardware — explicitly disabled |

## Quick Start

### Arch Linux

```bash
git clone https://github.com/wolffcatskyy/linux-mac.git
cd linux-mac/packaging/arch
makepkg -s
sudo pacman -U linux-macpro61-*.pkg.tar.zst
# Add a systemd-boot entry, then: sudo poweroff
# IMPORTANT: Always power off, never reboot, when switching kernels (Apple EFI)
```

### Any Distribution

```bash
git clone https://github.com/wolffcatskyy/linux-mac.git
cd linux-mac
./scripts/build.sh
# Installs vmlinuz and modules to standard paths
# Add a bootloader entry, then: sudo poweroff
```

## Important

**Always power off (not reboot) when switching kernels.** Apple EFI needs a cold boot to reinitialize the GPU. Warm reboot = black screen.

## GPU Variants

| GPU | VRAM | Codename | PCI ID |
|-----|------|----------|--------|
| FirePro D300 | 2GB | Pitcairn | `1002:6819` |
| FirePro D500 | 3GB | Tahiti | `1002:6798` |
| FirePro D700 | 6GB | Tahiti XT | `1002:6798` |

All use the `amdgpu` driver with `CONFIG_DRM_AMDGPU_SI=y`. Userspace via Mesa `radeonsi` (OpenGL) and `RADV` (Vulkan).

## macOS Tahoe in KVM

Run macOS on a modern Linux kernel with actively maintained drivers — no OCLP, no shimming 2013-era kexts into a modern OS.

See [docs/kvm-macos.md](docs/kvm-macos.md) for the full guide.

## Pre-configured ISO (Coming Soon)

**[AnduinOS](https://www.anduinos.com/)** — Ubuntu LTS with GNOME. Boot a USB, install, everything works. Includes the custom kernel, Mesa 26.1-dev with RADV Vulkan, and macOS Tahoe KVM launcher.

## Roadmap

| Status | Milestone |
|--------|-----------|
| Done | Kernel 7.0-rc1 with built-in amdgpu, all GPU variants, verified against lspci |
| Done | 15s boot, 12 modules, compiler-optimized for Ivy Bridge |
| Done | KVM + macOS Tahoe virtualization |
| Coming | AnduinOS pre-configured ISO |
| Coming | Pre-built packages (Arch AUR, Fedora COPR, openSUSE OBS) |
| Planned | CachyOS patches (BORE scheduler, BBR3) when 7.x compatible |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Kernel configs and patches: GPL-2.0 (same as the Linux kernel)
Scripts and documentation: MIT
