# Mac Pro 7,1 Kernel Patches

Place `.patch` files here. They will be applied during the build.

## Planned Patches

### t2-audio.patch (likely needed)
The T2 chip mediates audio on the 7,1. Mainline Linux may not
correctly route audio through the T2. The t2linux.org community
maintains patches for T2 audio support.

Status: Investigate patches from https://github.com/t2linux/linux-t2-patches
and adapt for this kernel config.

### t2-bluetooth.patch (likely needed)
Bluetooth is routed through the T2 chip and requires special
firmware loading. The t2linux community has working patches.

Status: Investigate t2linux patches for Bluetooth support.

### thunderbolt-titan-ridge.patch (maybe)
The 7,1 uses Intel Titan Ridge (JHL7540) Thunderbolt 3 controllers.
Mainline support should work, but there may be quirks with Apple's
implementation (especially for hot-plugging Thunderbolt displays
through MPX modules).

Status: Needs testing on hardware to identify any issues.
