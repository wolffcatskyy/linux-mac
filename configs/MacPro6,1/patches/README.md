# Mac Pro 6,1 Kernel Patches

Place `.patch` files here. They will be applied during the build.

## Planned Patches

### thunderbolt-silence-hotplug.patch
Reduce excessive log messages from Thunderbolt hotplug detection on the 6,1.
The DSL5520 controller generates constant re-enumeration events, especially
with Thunderbolt displays connected.

Status: Not yet written — needs testing on hardware to identify exact
log sources and write targeted suppression.

### acpi-darwin-osi.patch (maybe)
Force `_OSI("Darwin")` responses to calm Apple EFI firmware. May reduce
ACPI errors in dmesg. Needs testing to confirm benefit vs side effects.
