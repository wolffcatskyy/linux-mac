# GPU Acceleration on Mac Pro 6,1

## The Full Stack

The Mac Pro 6,1 ships with dual AMD FirePro GPUs. Under Linux, GPU acceleration uses a three-layer stack:

```
Application (OpenGL / Vulkan / OpenCL / VA-API)
    |
Mesa userspace drivers (radeonsi, RADV, rusticl)
    |
amdgpu kernel driver (SI support enabled)
    |
GPU hardware (D300 / D500 / D700)
```

Every layer is open-source, actively maintained, and improving with each release.

## GPU Variants

| GPU | VRAM | Codename | GCN | PCI ID | Shader Cores |
|-----|------|----------|-----|--------|-------------|
| FirePro D300 | 2GB GDDR5 | Pitcairn | 1.0 (SI) | `1002:6819` | 1280 |
| FirePro D500 | 3GB GDDR5 | Tahiti | 1.0 (SI) | `1002:6798` | 1792 |
| FirePro D700 | 6GB GDDR5 | Tahiti XT | 1.0 (SI) | `1002:6798` | 2048 (32 CUs) |

All are GCN 1.0 (Southern Islands). The `amdgpu` kernel driver handles them with `amdgpu.si_support=1`. The older `radeon` driver also supports them but lacks modern features like Vulkan.

## What Works Today

### OpenGL (radeonsi)

Full OpenGL 4.6 support via Mesa's `radeonsi` driver. This is mature, stable, and performant.

```
$ glxinfo | grep "OpenGL version"
OpenGL version string: 4.6 (Compatibility Profile) Mesa 26.1.0-devel
```

### Vulkan (RADV)

Vulkan 1.3+ via Mesa's `RADV` driver. Supports most modern Vulkan applications.

```
$ vulkaninfo --summary
GPU0: AMD RADV TAHITI (LLVM 19.1.7)
  Vulkan 1.4.341
```

### Video Decode (VA-API / UVD)

Hardware video decode via AMD's UVD (Unified Video Decoder):

| Codec | Status |
|-------|--------|
| H.264 / AVC | Hardware decode |
| MPEG-2 | Hardware decode |
| VC-1 | Hardware decode |
| H.265 / HEVC | Not supported (needs GCN 2.0+) |
| VP9 / AV1 | Not supported |

```
$ vainfo
Driver version: Mesa Gallium driver 26.1.0-devel for AMD Radeon R9 200 / HD 7900 Series
```

### Video Encode (VCE)

Hardware video encode via AMD's VCE (Video Coding Engine):
- H.264 encoding supported
- Used by OBS, FFmpeg, and other tools

### OpenCL Compute (rusticl)

OpenCL via Mesa's `rusticl` backend. ROCm does not support Southern Islands GPUs.

```bash
# Enable rusticl
export RUSTICL_ENABLE=radeonsi

# Verify
clinfo | grep "Device Name"
```

### Display Output

All 6 Mini DisplayPort outputs work (3 per GPU). HDMI via adapter supported. Audio over DP/HDMI works.

## What Doesn't Work

| Feature | Reason |
|---------|--------|
| ROCm / HIP | AMD dropped SI support; minimum is GCN 3.0 (Fiji) |
| HEVC decode | Hardware UVD too old (GCN 1.0) |
| VP9 / AV1 decode | Not present in hardware |
| DisplayPort MST (daisy-chain) | Not supported by amdgpu SI |
| FreeSync / VRR | Requires GCN 2.0+ |
| Power management (pp_dpm) | PowerPlay sysfs not available for SI GPUs |

## Mesa Version Matters

Mesa improvements for GCN 1.0 have been significant in recent releases:

| Mesa Version | Key Improvements |
|-------------|-----------------|
| 24.0+ | radeonsi NIR backend (replaces TGSI), better shader compilation |
| 24.2+ | RADV improvements for older GCN |
| 25.0+ | rusticl OpenCL stability |
| 26.1 (current) | Continued radeonsi/RADV refinement |

**Recommendation:** Use the latest Mesa available. On CachyOS/Arch:
```bash
# Stable
sudo pacman -S mesa vulkan-radeon

# Bleeding edge (mesa-git from CachyOS repos)
sudo pacman -S mesa-git
```

This system is running `mesa-git 26.1.0-devel` from CachyOS.

## Dual GPU Usage

Both GPUs are available. By default, GPU 1 (card1) handles display. GPU 0 (card0) is available for compute or offload:

```bash
# Check both GPUs
ls /dev/dri/renderD*
# renderD128 = GPU 0, renderD129 = GPU 1

# Run an app on the second GPU
DRI_PRIME=1 glxgears

# Assign specific GPU for Vulkan
MESA_VK_DEVICE_SELECT=1002:6798:1 vulkan-app
```

## Performance Tuning

```bash
# Shader cache (reduces stutter on repeated workloads)
export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa_shader_cache"
export MESA_SHADER_CACHE_MAX_SIZE=4G

# Threading (significant for OpenGL)
export mesa_glthread=true

# RADV optimizations
export RADV_PERFTEST=gpl,nggc
```

## Kernel Parameters

The linux-macpro61 kernel and ISO set these automatically:

```
amdgpu.si_support=1    # Enable Southern Islands in amdgpu
radeon.si_support=0    # Disable Southern Islands in radeon (avoid conflicts)
amdgpu.dc=0            # Display Core off (SI uses legacy display path)
```

The modprobe config (`/etc/modprobe.d/macpro-gpu.conf`) ensures these persist after installation.

## Acceleration Roadmap

| Status | Feature | Details |
|--------|---------|---------|
| Done | OpenGL 4.6 | radeonsi, mature and stable |
| Done | Vulkan 1.3+ | RADV, works for most applications |
| Done | VA-API decode | H.264, MPEG-2, VC-1 via UVD |
| Done | VCE encode | H.264 hardware encoding |
| Done | OpenCL | Via rusticl (Mesa) |
| Done | Multi-GPU | Both GPUs accessible, DRI_PRIME offload |
| Done | DP audio | HDMI/DP audio via amdgpu |
| Investigating | macOS GPU passthrough | PVG (ParavirtualizedGraphics) for KVM — see [pvg-linux.md](pvg-linux.md) |
| Not possible | ROCm / HIP | AMD hardware requirement: GCN 3.0+ |
| Not possible | HEVC / VP9 / AV1 decode | Hardware limitation |

## macOS GPU Acceleration (KVM)

macOS Tahoe runs in KVM/QEMU on this kernel. Currently **without GPU acceleration** (virtio-vga only). The path to GPU acceleration is through ParavirtualizedGraphics (PVG):

```
macOS Metal app
  -> PVG guest driver (built into macOS)
  -> apple-gfx-pci (QEMU 10.0+)
  -> PVG host implementation (needs reverse engineering)
  -> Mesa radeonsi/RADV
  -> amdgpu kernel driver
  -> D300/D500/D700 hardware
```

The host side doesn't exist on Linux yet. See [pvg-linux.md](pvg-linux.md) for the full analysis and roadmap.

## Compared to macOS (OCLP)

Apple dropped macOS support for the 6,1. OCLP tries to bring it back by shimming 2013-era GPU kexts into modern macOS. Here's how the two approaches compare:

| | Linux (this project) | macOS (OCLP) |
|---|---|---|
| GPU driver age | 2026 (actively maintained) | 2013 kexts (shimmed) |
| OpenGL | 4.6 | 4.1 (Apple's last) |
| Vulkan | 1.3+ via RADV | MoltenVK (translation layer) |
| Metal | N/A | Shimmed, fragile |
| Video decode | UVD (H.264) | VDA (similar) |
| Stability | Solid (native driver) | Breaks on macOS updates |
| Future | Improving every Mesa release | Deprecated, OCLP may drop 6,1 |

## Further Reading

- [mesa.md](mesa.md) -- Mesa setup, environment variables, troubleshooting
- [pvg-linux.md](pvg-linux.md) -- ParavirtualizedGraphics roadmap for macOS KVM
- [kvm-macos.md](kvm-macos.md) -- macOS Tahoe KVM setup guide
