# linux-mac

Custom Linux kernels purpose-built for Apple Mac hardware. Minimal, performant, and tuned for the exact chips in your machine — not a generic distro kernel with 5,000 modules you'll never use.

## 🔥 Headlines

### 1. A Supercharged Linux Purpose-Built for Your Mac
Custom kernel tuned for the exact hardware — Ivy Bridge Xeon, dual FirePro D700s, 12 years of kernel improvements baked in. Faster boot, lower memory footprint, built-in drivers, no initramfs. Everything compiled for your specific CPU.

### 2. Run macOS Tahoe on Mac Pro 6,1 — Today
OCLP doesn't support Tahoe on the 6,1 yet, and may never fully. This project does. macOS Tahoe runs in KVM/QEMU on the custom Linux kernel above, right now, on your Mac Pro.

### 3. Eventually — macOS Virtualized Faster Than Bare Metal
As the open-source PVG (ParavirtualizedGraphics) Linux host implementation matures, macOS in the VM gets full GPU acceleration through the Linux 6.19 amdgpu driver — which has had 9 years of improvements since Apple abandoned these GPUs. OCLP shims dead drivers. This project uses living ones.

## Why?

Apple drops macOS support for older Intel Macs, but the hardware doesn't suddenly become useless. A 2013 Mac Pro is still a powerful machine — dual workstation GPUs, Xeon processor, 64GB RAM. The limiting factor is software support, not horsepower.

A stock distro kernel ships with thousands of modules for hardware you'll never have. This project strips all that away and builds a kernel specifically for your Mac model:

- **Drivers compiled in**, not loaded as modules — faster boot, simpler system
- **CPU-optimized** for your specific Intel architecture
- **No initramfs needed** — the kernel has everything built in
- **Tuned scheduling, memory management, and I/O** for your exact RAM and storage
- **12 years of upstream improvements** since the Mac Pro 6,1 shipped

## Supported Models

| Model | Identifier | Status | Maintainer |
|-------|-----------|--------|------------|
| Mac Pro (Late 2013) | `MacPro6,1` | ✅ Active | @your-username |
| *Your Mac here* | *submit a PR* | 🔜 | *you?* |

## Quick Start (Arch Linux)

```bash
# Clone
git clone https://github.com/your-username/linux-mac.git
cd linux-mac/packaging/arch

# Build
makepkg -s

# Install alongside stock kernel
sudo pacman -U linux-macpro61-*.pkg.tar.zst

# Update bootloader (systemd-boot)
# Add entry pointing to vmlinuz-linux-macpro61
# No initrd line needed — everything is built in

# Reboot and select the new kernel
```

## Repo Structure

```
linux-mac/
├── configs/
│   └── MacPro6,1/
│       ├── config              # kernel .config
│       ├── README.md           # hardware matrix, what works
│       ├── patches/            # model-specific kernel patches
│       ├── sysctl.d/
│       │   └── 99-macpro.conf  # performance tuning
│       └── fan/
│           └── macfanctld.conf # fan curve profiles
├── packaging/
│   ├── arch/
│   │   └── PKGBUILD           # AUR-ready
│   ├── debian/                 # future
│   └── fedora/                 # future
├── scripts/
│   └── build.sh               # universal build script
├── docs/
│   ├── mesa.md                # GPU userspace setup
│   ├── kvm-macos.md           # macOS Tahoe VM guide
│   └── pvg-linux.md           # PVG reimplementation roadmap
└── README.md
```

## Performance Expectations

Compared to a stock distro kernel on the same hardware:

| Metric | Improvement | Notes |
|--------|------------|-------|
| Boot time | 30-50% faster | No module loading, no initramfs |
| Memory footprint | 100-300MB less | Fewer loaded modules/subsystems |
| CPU-bound tasks | 2-10% | Compiled for Ivy Bridge-EP specifically |
| I/O / Storage | 5-15% | Tuned scheduler and block layer |
| System responsiveness | Noticeably snappier | 1000Hz tick, PREEMPT, autogroup |
| GPU stability | Potentially significant | Built-in amdgpu, correct firmware, no driver conflicts |

## macOS Tahoe in KVM

See [docs/kvm-macos.md](docs/kvm-macos.md) for the full guide. The short version:

1. Build and install the custom kernel (includes KVM and virtio support)
2. Set up QEMU with OpenCore bootloader
3. Boot macOS Tahoe
4. It works. No OCLP. No legacy kext shims.

For the GPU acceleration roadmap (making macOS faster than bare metal), see [docs/pvg-linux.md](docs/pvg-linux.md).

## Contributing

The best way to contribute is to add support for your Mac model:

1. Install a standard distro on your Mac
2. Document what works and what doesn't
3. Run `make localmodconfig` to get a starting config
4. Trim it following the pattern in `configs/MacPro6,1/`
5. Test, iterate, submit a PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Kernel configs and patches: GPL-2.0 (same as the Linux kernel)
Scripts and documentation: MIT
