# linux-mac

Linux on Apple Mac Pro 6,1 (Late 2013) -- the definitive support project.

Custom kernels, hardware documentation, GPU configuration, performance tuning, and macOS virtualization for the "trash can" Mac Pro. Everything you need to run Linux as a first-class operating system on this hardware.

## Overview

The Mac Pro 6,1 shipped in late 2013 with workstation-grade components: Xeon E5 processors (4 to 12 cores), dual AMD FirePro GPUs, Thunderbolt 2, and up to 128GB RAM. Apple dropped macOS support years ago, but the hardware is still capable. Linux gives it a second life with modern drivers, active upstream development, and full GPU acceleration.

This project provides:

- **Custom kernel configs** built specifically for Mac Pro 6,1 hardware -- no unnecessary modules, no initramfs, everything compiled in
- **Hardware documentation** covering every component, driver, and known issue across all model variants
- **GPU support** for all three FirePro variants (D300, D500, D700) via the amdgpu driver with GCN 1.0 Southern Islands support
- **Performance tuning** via sysctl profiles and fan curve configurations
- **macOS Tahoe virtualization** through KVM/QEMU on the custom kernel, without OCLP or legacy kext shims
- **Packaging** for any Linux distribution -- PKGBUILD for Arch Linux (AUR-ready), with Fedora COPR and openSUSE OBS support planned

## Supported GPU Variants

All Mac Pro 6,1 configurations ship with dual AMD FirePro GPUs. All three variants are supported:

| GPU | VRAM | Codename | GCN Generation | PCI ID |
|-----|------|----------|----------------|--------|
| FirePro D300 | 2GB | Pitcairn | GCN 1.0 (Southern Islands) | `1002:6819` |
| FirePro D500 | 3GB | Tahiti | GCN 1.0 (Southern Islands) | `1002:6798` |
| FirePro D700 | 6GB | Tahiti XT | GCN 1.0 (Southern Islands) | `1002:6798` |

All variants use the `amdgpu` kernel driver with SI (Southern Islands) support enabled and the `radeonsi` (OpenGL) / `RADV` (Vulkan) Mesa drivers in userspace. Linux kernel 6.19 marks a maturity milestone for GCN 1.0 support in amdgpu -- these GPUs now have better driver support under Linux than they ever did under macOS with OCLP shimming deprecated kexts from 2013.

## Model Variants

| Model | CPU | GPU | RAM |
|-------|-----|-----|-----|
| Base | E5-1620 v2 (4C/8T, 3.7GHz) | 2x D300 (2GB) | 12GB |
| Mid | E5-1650 v2 (6C/12T, 3.5GHz) | 2x D500 (3GB) | 16GB |
| High | E5-1680 v2 (8C/16T, 3.0GHz) | 2x D700 (6GB) | 32/64GB |
| BTO Max | E5-2697 v2 (12C/24T, 2.7GHz) | 2x D700 (6GB) | 64GB |

All CPU variants are Ivy Bridge-EP (Xeon E5 v2). The kernel config targets the common architecture; no per-CPU changes are needed.

## Why a Custom Kernel

A stock distribution kernel ships with thousands of modules for hardware you will never have. This project strips all of that away and builds a kernel specifically for the Mac Pro 6,1:

- **Drivers compiled in**, not loaded as modules -- faster boot, simpler system
- **CPU-optimized** for Ivy Bridge-EP Xeon processors
- **No initramfs needed** -- the kernel has everything built in
- **Tuned scheduling, memory management, and I/O** for the specific hardware profile
- **12 years of upstream improvements** since the Mac Pro 6,1 shipped

### Performance Expectations

Compared to a stock distribution kernel on the same hardware:

| Metric | Improvement | Notes |
|--------|------------|-------|
| Boot time | 30-50% faster | No module loading, no initramfs |
| Memory footprint | 100-300MB less | Fewer loaded modules and subsystems |
| CPU-bound tasks | 2-10% | Compiled for Ivy Bridge-EP specifically |
| I/O and storage | 5-15% | Tuned scheduler and block layer |
| System responsiveness | Noticeably improved | 1000Hz tick, PREEMPT, autogroup |
| GPU stability | Potentially significant | Built-in amdgpu, correct firmware, no driver conflicts |

## macOS Tahoe in KVM

Apple dropped macOS support, and OCLP's path forward for the 6,1 means shimming GPU kexts scavenged from Mavericks (2013) -- 12-year-old driver code patched into a modern OS. This project takes the opposite approach: macOS Tahoe runs in KVM/QEMU on a modern Linux kernel with actively maintained amdgpu drivers underneath.

See [docs/kvm-macos.md](docs/kvm-macos.md) for the full guide. The short version:

1. Build and install the custom kernel (includes KVM and virtio support)
2. Set up QEMU with OpenCore bootloader
3. Boot macOS Tahoe
4. It works. No OCLP. No legacy kext shims.

For the GPU acceleration roadmap (ParavirtualizedGraphics host-side reimplementation), see [docs/pvg-linux.md](docs/pvg-linux.md).

## Quick Start

The kernel config is distro-agnostic -- it works on any Linux distribution. Build it from source with the universal build script, or use the distro-specific packaging below.

### Any Distribution (from source)

```bash
git clone https://github.com/wolffcatskyy/linux-mac.git
cd linux-mac
./scripts/build.sh
# Installs vmlinuz and modules to standard paths
# Add a bootloader entry for the new kernel
# No initrd line needed -- everything is built in
```

### Arch Linux (PKGBUILD)

```bash
git clone https://github.com/wolffcatskyy/linux-mac.git
cd linux-mac/packaging/arch
makepkg -s
sudo pacman -U linux-macpro61-*.pkg.tar.zst
# Add a systemd-boot entry pointing to vmlinuz-linux-macpro61
# No initrd line needed -- everything is built in
```

### Fedora / openSUSE

Pre-built packages via Fedora COPR and openSUSE OBS are planned. In the meantime, use the universal build script above.

## Repository Structure

```
linux-mac/
├── configs/
│   └── MacPro6,1/
│       ├── config              # kernel .config
│       ├── README.md           # hardware matrix, driver mapping, known issues
│       ├── patches/            # model-specific kernel patches
│       ├── sysctl.d/
│       │   └── 99-macpro.conf  # performance tuning
│       └── fan/
│           └── macfanctld.conf # fan curve profiles
├── packaging/
│   ├── arch/
│   │   └── PKGBUILD           # AUR-ready
│   ├── fedora/                 # planned (COPR)
│   └── opensuse/              # planned (OBS)
├── scripts/
│   └── build.sh               # universal build script
├── docs/
│   ├── mesa.md                # GPU userspace setup
│   ├── kvm-macos.md           # macOS Tahoe VM guide
│   └── pvg-linux.md           # PVG reimplementation roadmap
└── README.md
```

## Hardware Support Status

| Feature | Status | Notes |
|---------|--------|-------|
| Display (DisplayPort) | Working | Via amdgpu + DC |
| Display (HDMI) | Working | Via amdgpu + DC |
| Display (Thunderbolt) | Partial | Works with log spam -- see known issues |
| OpenGL | Working | Via Mesa radeonsi |
| Vulkan | Working | Via Mesa RADV |
| GPU Compute | Working | HSA/OpenCL via ROCm or Mesa |
| Ethernet | Working | Both ports via tg3 (Broadcom BCM57762) |
| Wi-Fi | Requires firmware | Broadcom BCM4360 needs proprietary firmware |
| Audio (3.5mm) | Working | Intel HDA + Cirrus Logic CS4206 |
| Audio (HDMI/DP) | Working | Via amdgpu HDMI audio |
| Thunderbolt 2 | Partial | Intel DSL5520, hotplug log spam |
| USB 3.0 | Working | Via xHCI |
| Fan control | Working | Via applesmc + macfanctld |
| Temperature sensors | Working | Via applesmc + hwmon |
| Sleep/Wake | Disabled | Explicitly disabled — workstation kernel, if it's on it's on |

See [configs/MacPro6,1/README.md](configs/MacPro6,1/README.md) for full hardware details, PCI device IDs, and known issue workarounds.

## Roadmap

| Status | Milestone |
|--------|-----------|
| DONE | Custom kernel booting on Mac Pro 6,1 (all GPU variants: D300, D500, D700) |
| DONE | Built-in drivers -- amdgpu with firmware, tg3, Apple hardware (applesmc, SSD, USB, audio) |
| DONE | 42% faster boot (21s vs 36s userspace) compared to stock distribution kernels |
| IN PROGRESS | BORE scheduler, march=ivybridge optimization, and CachyOS performance patches |
| PLANNED | Bazzite (gaming/media) and Aurora (workstation) custom images |
| PLANNED | macOS Tahoe KVM/QEMU ready-to-run VM configuration |
| PLANNED | Pre-built kernel packages (Arch AUR, Fedora COPR, openSUSE OBS) |
| PLANNED | Community testing for D300 and D500 GPU variants |

## Contributing

The best way to contribute is to add support for your Mac model:

1. Install a standard distribution on your Mac
2. Document what works and what does not
3. Run `make localmodconfig` to get a starting config
4. Trim it following the pattern in `configs/MacPro6,1/`
5. Test, iterate, submit a PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Kernel configs and patches: GPL-2.0 (same as the Linux kernel)
Scripts and documentation: MIT
