# Mac Pro 5,1 Kernel Patches

Place `.patch` files here. They will be applied during the build.

## Planned Patches

### efi-mixed-32bit-boot.patch (maybe)
The Mid 2010 Mac Pro 5,1 uses 32-bit EFI firmware to boot a 64-bit OS.
`CONFIG_EFI_MIXED=y` handles this in mainline, but there may be edge
cases with Apple's EFI implementation that need patching.

Status: Needs testing on actual 2010 hardware to determine if mainline
EFI_MIXED support works without issues.

### ichr-ahci-link-power.patch (maybe)
The ICH10 AHCI controller may benefit from aggressive link power
management tuning for better idle power consumption with spinning
3.5" drives. Needs testing to confirm benefit vs reliability.

Status: Not yet written — needs hardware testing.
