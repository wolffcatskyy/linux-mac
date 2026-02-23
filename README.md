# linux-mac

Linux on Apple Mac Pro 6,1 (Late 2013) -- the definitive support project.

Custom kernels, hardware documentation, GPU configuration, performance tuning, and macOS virtualization for the "trash can" Mac Pro. Everything you need to run Linux as a first-class operating system on this hardware.

## Overview

The Mac Pro 6,1 shipped in late 2013 with workstation-grade components: Xeon E5 processors (4 to 12 cores), dual AMD FirePro GPUs, Thunderbolt 2, and up to 128GB RAM. Apple dropped macOS support years ago, but the hardware is still capable. Linux gives it a second life with modern drivers, active upstream development, and full GPU acceleration.

The kernel config is based on 7.0-rc1 and includes CachyOS patches with AMD GCN 1.0 (Southern Islands) fixes cherry-picked from upstream. These address stability and correctness issues specific to Tahiti/Pitcairn silicon.

This project provides:

- **Custom kernel configs** built specifically for Mac Pro 6,1 hardware -- 6 modules loaded vs 115 on a stock kernel, 42% faster boot
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

All variants use the `amdgpu` kernel driver with SI (Southern Islands) support enabled and the `radeonsi` (OpenGL) / `RADV` (Vulkan) Mesa drivers in userspace. Linux kernel 7.0 marks a maturity milestone for GCN 1.0 support in amdgpu -- these GPUs now have better driver support under Linux than they ever did under macOS with OCLP shimming deprecated kexts from 2013.

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

- **6 modules vs 115 stock** -- only what the hardware actually needs
- **42% faster boot** -- 21s vs 36s userspace on identical hardware
- **CPU-optimized** for Ivy Bridge-EP Xeon processors
- **amdgpu as a module (=m)** loaded via initramfs -- required for Apple EFI (see Critical Gotchas)
- **Tuned scheduling, memory management, and I/O** for the specific hardware profile
- **CachyOS patches (BORE scheduler, performance tuning)** with GCN 1.0 Southern Islands fixes from upstream

### Performance Expectations

Compared to a stock distribution kernel on the same hardware:

| Metric | Improvement | Notes |
|--------|------------|-------|
| Boot time | 42% faster | 6 modules loaded vs 115, measured on identical hardware |
| Memory footprint | 100-300MB less | Fewer loaded modules and subsystems |
| CPU-bound tasks | 2-10% | Compiled for Ivy Bridge-EP specifically |
| I/O and storage | 5-15% | Tuned scheduler and block layer |
| System responsiveness | Noticeably improved | 1000Hz tick, PREEMPT, autogroup |
| GPU stability | Potentially significant | Correct amdgpu module loading, correct firmware, no driver conflicts |

## Critical Gotchas (Apple EFI + amdgpu)

These are hard-won lessons from running amdgpu on Mac Pro 6,1 hardware. Getting any one of these wrong results in a black screen or unbootable system.

**Always poweroff, never reboot, when switching kernels.** Apple EFI does not fully reinitialize the GPU on warm reboot. A cold boot (full power off) clears GPU state completely. Warm reboot leaves the GPU in an inconsistent state and you get a black screen. This applies when switching between stock and custom kernels, or after any kernel update.

**amdgpu MUST be `=m` (module), NOT `=y` (built-in).** On Apple EFI hardware, building amdgpu directly into the kernel (`CONFIG_DRM_AMDGPU=y`) causes initialization failures. The driver must load as a module after the EFI framebuffer hands off. This means an initramfs is required.

**initramfs MUST include the amdgpu module.** In `mkinitcpio.conf`, set `MODULES=(amdgpu)` so the module is available early in boot. Without this, the kernel boots to a black screen because no GPU driver loads before userspace.

**kexec is broken on Apple EFI.** Even a known-working kernel will fail to boot via `kexec`. Apple's EFI firmware does not support the kexec reboot path. Always do a full reboot through firmware.

**apple-gmux is unnecessary and harmful.** The `apple-gmux` driver handles iGPU/dGPU switching on MacBooks. The Mac Pro 6,1 has no iGPU -- it only has dual discrete FirePro GPUs. Loading apple-gmux on this hardware creates 1000+ D-state kworker threads that waste CPU. Disable with `# CONFIG_APPLE_GMUX is not set`.

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
# initramfs required -- amdgpu must load as module on Apple EFI
```

### Arch Linux (PKGBUILD)

```bash
git clone https://github.com/wolffcatskyy/linux-mac.git
cd linux-mac/packaging/arch
makepkg -s
sudo pacman -U linux-macpro61-*.pkg.tar.zst
# Add a systemd-boot entry pointing to vmlinuz-linux-macpro61
# Ensure MODULES=(amdgpu) in /etc/mkinitcpio.conf, then: mkinitcpio -P
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
| DONE | Minimal driver set -- amdgpu (module) with firmware, tg3, Apple hardware (applesmc, SSD, USB, audio) |
| DONE | 42% faster boot (21s vs 36s userspace), 6 modules vs 115 stock |
| IN PROGRESS | BORE scheduler, march=ivybridge optimization, and CachyOS performance patches |
| COMING SOON | **[AnduinOS](https://www.anduinos.com/)** and **[AerynOS](https://aerynos.com/)** pre-configured ISOs -- boot, install, done |
| COMING SOON | macOS Tahoe KVM one-click setup (auto-downloads recovery, configures QEMU, desktop icon) |
| COMING SOON | Mesa 26.1-dev (git) with RADV Vulkan -- latest GCN 1.0 fixes |
| PLANNED | Pre-built kernel packages (Arch AUR, Fedora COPR, openSUSE OBS) |
| PLANNED | Community testing for D300 and D500 GPU variants |

## Pre-configured ISOs (Coming Soon)

Why spend hours configuring when you can boot a USB stick and have everything working?

We are building ready-to-install ISOs specifically for the Mac Pro 6,1:

| ISO | Base | Desktop | Target |
|-----|------|---------|--------|
| **[AnduinOS](https://www.anduinos.com/)** | Ubuntu LTS | GNOME (Windows-like UX) | Users who want stability and familiarity |
| **[AerynOS](https://aerynos.com/)** | Serpent OS | COSMIC/GNOME | Users who want a modern, performance-focused system |

Both ISOs include:
- **Custom kernel** with hardware-specific optimizations (amdgpu=m, embedded firmware, no bloat)
- **Mesa 26.1-dev** with RADV Vulkan for full GPU acceleration on GCN 1.0
- **macOS Tahoe KVM** one-click desktop launcher (downloads recovery from Apple, pre-configures QEMU)
- **Pre-configured boot entries** for Mac Pro 6,1 EFI
- **Fan control** via applesmc + macfanctld
- **No configuration required** -- boot the USB, click install, done

### Why Two ISOs?

Different users want different things. [AnduinOS](https://www.anduinos.com/) targets users migrating from Windows or macOS who want a familiar desktop. [AerynOS](https://aerynos.com/) targets power users and developers who want a cutting-edge system with the latest packages.

Both ship the same custom kernel and GPU stack. The difference is the userland.

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
