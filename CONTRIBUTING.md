# Contributing to linux-mac

## Adding Support for a New Mac Model

This is the single most valuable contribution. Here's how:

### 1. Install Linux on Your Mac

Any distro works. Arch and Fedora tend to have the newest kernels.

### 2. Document Your Hardware

```bash
lspci -nn > lspci.txt
lsusb > lsusb.txt
cat /proc/cpuinfo > cpuinfo.txt
dmesg > dmesg.txt
lsmod > lsmod.txt
```

### 3. Generate a Starting Config

```bash
make localmodconfig
cp .config starting-config.txt
```

### 4. Create the Config Directory

```
configs/YourModel/
├── config          # kernel .config
├── README.md       # hardware matrix (use MacPro6,1 as template)
├── patches/        # any model-specific patches
├── sysctl.d/
│   └── 99-yourmodel.conf
└── fan/
    └── fan.conf    # if applicable
```

### 5. Trim the Config

Follow the pattern in `configs/MacPro6,1/config`:

- Identify exact hardware from `lspci`
- Set your drivers to `=y` (built-in)
- Disable drivers for hardware you don't have
- Set CPU optimization for your architecture
- Build firmware blobs into the kernel

### 6. Test

- Build the kernel
- Boot it (keep stock kernel as fallback!)
- Verify all hardware works
- Document what works/doesn't in your README.md

### 7. Submit a PR

Include your config directory, test results, and `lspci -nn` output.

## Improving Existing Configs

- Fix hardware that doesn't work
- Add patches for model-specific issues
- Tune performance settings
- Update for newer kernel versions

## PVG Linux Host Implementation

See [docs/pvg-linux.md](docs/pvg-linux.md). Most impactful contributions:

- Protocol documentation from QEMU source analysis
- Mesa/Vulkan integration expertise
- Testing on different GPU + macOS combinations

## Code Style

- Shell scripts: `shellcheck` clean
- Kernel configs: commented, organized by subsystem
- Documentation: clear, practical, tested

## Reporting Issues

Include: Mac model/variant, kernel version, relevant `dmesg` output, steps to reproduce.
