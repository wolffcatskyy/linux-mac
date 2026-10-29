# linux-mac

> Archived project — retained for historical reference.

This repository explored running macOS on Linux/KVM on the Mac Pro 6,1, with a custom CachyOS-based kernel configuration and supporting packaging.

The kernel and Mac Pro hardware work here remain the useful part of the project. The experimental macOS GPU-paravirtualization roadmap has been removed because it was superseded by [reims-vgpu](https://github.com/steelbrain/reims-vgpu), which provides the working PVG host implementation and Linux Vulkan backend.

For the background and hardware context that motivated this work, see [Mac Pro: From Trash Can to AI Workstation](https://kovasky.me/blogs/mac_pro_trashcan_ai/).

This repository is no longer actively developed. New macOS VM GPU work should use Reims instead.

## What remains

- Mac Pro 6,1 kernel configuration and hardware-specific settings
- Arch packaging and kernel build patches
- Supporting scripts and configuration files

## License

GPL-2.0. See [LICENSE](LICENSE).
