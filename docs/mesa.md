# Mesa GPU Userspace Setup for Mac Pro 6,1

## Overview

The Mac Pro 6,1's FirePro D700 GPUs use two Mesa drivers:

- **radeonsi** — OpenGL driver for GCN GPUs
- **RADV** — Vulkan driver for GCN GPUs

Both are actively maintained in Mesa and receive regular improvements.

## Recommended Mesa Version

Use the latest stable Mesa release available for your distribution. Mesa 24.x+ is recommended for best GCN 1.0 support.

```bash
# Arch Linux (usually up to date)
sudo pacman -S mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon

# Verify drivers
glxinfo | grep "OpenGL renderer"
# Should show: AMD FirePro D700 (tahiti, ...)

vulkaninfo --summary
# Should show: RADV TAHITI
```

## Environment Variables

```bash
# Force radeonsi if multiple GPUs cause confusion
export MESA_LOADER_DRIVER_OVERRIDE=radeonsi

# For Vulkan, select the correct GPU
export RADV_PERFTEST=gpl  # Enable graphics pipeline library
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json

# Debug (if having issues)
export MESA_DEBUG=1
export RADV_DEBUG=info
```

## Multi-GPU Configuration

The Mac Pro 6,1 has **two** D700 GPUs. By default, Linux will use the first one for display. For compute workloads across both:

```bash
# List GPU devices
ls /dev/dri/card* /dev/dri/renderD*

# Typically:
# /dev/dri/card0 — First D700 (display)
# /dev/dri/card1 — Second D700
# /dev/dri/renderD128 — First D700 (render node)
# /dev/dri/renderD129 — Second D700 (render node)

# Assign specific GPU to an application
DRI_PRIME=1 glxgears  # Run on second GPU
```

## Performance Tips

```bash
# Enable shader disk cache (significant for repeated workloads)
export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa_shader_cache"
export MESA_SHADER_CACHE_MAX_SIZE=4G

# radeonsi thread optimization
export mesa_glthread=true

# For RADV Vulkan
export RADV_PERFTEST=gpl,nggc
```

## Firmware

The kernel config builds firmware into the kernel image. If you need to verify firmware is loaded:

```bash
dmesg | grep -i firmware
dmesg | grep -i tahiti

# Should show successful firmware loading for tahiti_* blobs
# No "firmware failed" messages
```

## Xorg Configuration (if not using Wayland)

Xorg should auto-detect via modesetting. If you need manual config:

```
# /etc/X11/xorg.conf.d/20-amdgpu.conf
Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
    Option "TearFree" "true"
    Option "DRI" "3"
EndSection
```

## Wayland (Sway/Hyprland)

Wayland compositors work well with amdgpu. No special configuration needed beyond installing the compositor:

```bash
# Sway
sudo pacman -S sway

# Hyprland
sudo pacman -S hyprland
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `MESA-LOADER: failed to open radeonsi` | Install `mesa` package, check firmware |
| Vulkan not detected | Install `vulkan-radeon`, check `vulkaninfo` |
| Only one GPU visible | Check both cards in `lspci`, verify both have render nodes |
| Poor OpenGL performance | Enable `mesa_glthread=true` |
| Screen tearing | Enable TearFree in Xorg or use Wayland |
