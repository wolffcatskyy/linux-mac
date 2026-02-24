# linux-mac

Custom Linux kernel for the Mac Pro 6,1 (Late 2013). CachyOS-based with BORE scheduler, built-in drivers, embedded GPU firmware — boots to desktop with no initramfs required.

## What This Is

A kernel config and PKGBUILD for Linux 7.0 targeting Mac Pro 6,1 hardware. CachyOS 7.0 base with BORE scheduler and BBR3, Mac Pro drivers built-in, GPU firmware embedded in kernel.

- **All GPU variants** — D300 (Pitcairn), D500 (Tahiti), D700 (Tahiti XT), firmware baked in
- **CachyOS performance** — BORE scheduler, BBR3 congestion control, `-march=ivybridge -O3`
- **KVM built-in** — run macOS Tahoe in QEMU
- **NVMe + TRIM** — aftermarket NVMe drives work out of the box

## Hardware Support

| Feature | Status | Notes |
|---------|--------|-------|
| GPU (D300/D500/D700) | Working | amdgpu built-in, radeonsi/RADV via Mesa |
| Display (DP/HDMI) | Working | Via amdgpu + DC |
| Vulkan / OpenGL | Working | Mesa RADV / radeonsi |
| GPU Compute | Limited | OpenCL via rusticl only — no ROCm for Southern Islands |
| Ethernet | Working | Both ports via tg3 + Broadcom PHY |
| Wi-Fi | Proprietary | `broadcom-wl-dkms` (AUR) + headers package |
| Audio | Working | Intel HDA + Cirrus CS4206, HDMI/DP via amdgpu |
| USB 3.0 | Working | xHCI |
| Thunderbolt 2 | Partial | Works with log spam |
| NVMe + TRIM | Working | Built-in; enable `fstrim.timer` |
| Bluetooth | Working | Broadcom via btusb |
| KVM | Working | macOS Tahoe virtualization |
| Fans / Thermal | Working | applesmc + hwmon; install `macfanctld` (AUR) |
| Sleep/Wake | Disabled | Unreliable on this hardware |

## Quick Start

```bash
git clone https://github.com/wolffcatskyy/linux-mac.git
cd linux-mac/packaging/arch
makepkg -s
sudo pacman -U linux-macpro61-*.pkg.tar.zst
sudo poweroff  # Apple EFI needs cold boot — never reboot when switching kernels
```

## Important

**Always power off (not reboot) when switching kernels.** Apple EFI needs a cold boot to reinitialize the GPU.

## CachyOS Patches

Built on the CachyOS 7.0 patch set:
- **BORE** — Burst-Oriented Response Enhancer scheduler
- **BBR3** — Google TCP congestion control v3
- **CachyOS tweaks** — kernel optimizations
- **HDMI improvements** — display fixes

## Documentation

- [GPU Acceleration Guide](docs/gpu-acceleration.md) -- full stack explainer, what works, performance tuning, roadmap
- [Mesa Setup](docs/mesa.md) -- driver config, environment variables, multi-GPU
- [macOS Tahoe KVM](docs/kvm-macos.md) -- run macOS in a VM on this kernel
- [PVG Roadmap](docs/pvg-linux.md) -- GPU acceleration for macOS VMs
- [CachyOS ISO](https://github.com/wolffcatskyy/cachyos-macpro-iso) -- ready-to-build installer ISO

## Roadmap

| Status | Milestone |
|--------|-----------|
| Done | CachyOS 7.0 base with BORE, BBR3, built-in amdgpu |
| Done | All GPU variants, verified against lspci |
| Done | KVM + macOS Tahoe virtualization |
| Coming | CachyOS-based Mac Pro ISO (KDE Plasma) |
| Coming | Pre-built packages (Arch AUR, Fedora COPR, openSUSE OBS) |
| Planned | Driver trimming — remove unused hardware for faster builds |


## Boot Configuration

**systemd-boot** with ESP at \`/boot/efi/\` (FAT32).

### Gotchas

1. **ESP vs /boot** - pacman installs to \`/boot/\` (root partition) but systemd-boot reads from \`/boot/efi/\` (ESP). The package install hook syncs automatically.

2. **Cold boot only** - Apple EFI needs full power cycle for GPU init. The package masks \`reboot.target\` and aliases \`reboot\` to \`poweroff\` automatically.

3. **Boot entries** - Default: \`linux-macpro61.conf\` (custom kernel), fallback: \`arch-6.19.conf\` (stock).

## License

GPL-2.0 (same as the Linux kernel)
