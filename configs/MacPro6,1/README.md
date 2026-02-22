# Mac Pro 6,1 (Late 2013) — "Trash Can"

## Hardware Specifications

| Component | Details | Kernel Driver | Config Option |
|-----------|---------|--------------|---------------|
| **CPU** | Intel Xeon E5-1620 v2 to E5-2697 v2 (Ivy Bridge-EP) | — | Generic x86_64 (mainline has no Ivy Bridge-specific option) |
| **GPU** | 2x AMD FirePro D300/D500/D700 (Tahiti XT, GCN 1.0 / Southern Islands, PCI `1002:6798`) | `amdgpu` | `CONFIG_DRM_AMDGPU=y`, `CONFIG_DRM_AMDGPU_SI=y` |
| **Ethernet** | Broadcom BCM57762 Dual Gigabit | `tg3` | `CONFIG_TIGON3=y` |
| **Wi-Fi** | Broadcom BCM4360 802.11ac | `b43`/`brcmfmac` | `CONFIG_B43=y` or `CONFIG_BRCMFMAC=y` |
| **Audio** | Intel HDA + Cirrus Logic CS4206 | `snd_hda_intel` | `CONFIG_SND_HDA_INTEL=y`, `CONFIG_SND_HDA_CODEC_CIRRUS=y` |
| **Storage** | Apple PCIe SSD (AHCI) | `ahci` | `CONFIG_AHCI=y` |
| **Thunderbolt** | Intel DSL5520 (Thunderbolt 2) | `thunderbolt` | `CONFIG_THUNDERBOLT=y` |
| **USB** | Intel USB 3.0 (xHCI) | `xhci_hcd` | `CONFIG_USB_XHCI_HCD=y` |
| **Thermal** | Apple SMC | `applesmc` | `CONFIG_SENSORS_APPLESMC=y` |
| **Boot** | EFI | — | `CONFIG_EFI=y`, `CONFIG_EFI_STUB=y` |

## GPU Details

The D700 is based on AMD's Tahiti XT GPU (same silicon as the Radeon HD 7970). It's GCN 1.0 (Southern Islands). Despite Apple marketing referencing "FirePro D700", `lspci` identifies them as `1002:6798` and the amdgpu driver initializes them as TAHITI.

- **Kernel driver:** `amdgpu` with SI (Southern Islands) support — requires `CONFIG_DRM_AMDGPU_SI=y`
- **Firmware:** Tahiti: `tahiti_{ce,mc,me,pfp,rlc,smc}.bin` — Pitcairn: `pitcairn_{ce,mc,me,pfp,rlc,smc}.bin`
- **Mesa driver:** `radeonsi` (OpenGL), `RADV` (Vulkan)
- **Kernel 6.19:** Mature amdgpu SI support

## Hardware Compatibility Matrix

| Feature | Status | Notes |
|---------|--------|-------|
| Display (DP) | ✅ Works | Via amdgpu + DC |
| Display (HDMI) | ✅ Works | Via amdgpu + DC |
| Display (TB) | ⚠️ Works with issues | Log spam — see Known Issues |
| OpenGL | ✅ Works | Via Mesa radeonsi |
| Vulkan | ✅ Works | Via Mesa RADV |
| GPU Compute | ✅ Works | HSA/OpenCL via ROCm or Mesa |
| Ethernet | ✅ Works | Both ports via tg3 |
| Wi-Fi | ⚠️ Needs firmware | Broadcom requires proprietary firmware |
| Audio (3.5mm) | ✅ Works | Via snd_hda_intel + Cirrus codec |
| Audio (HDMI) | ✅ Works | Via amdgpu HDMI audio |
| Thunderbolt | ⚠️ Works with issues | Hotplug log spam |
| USB 3.0 | ✅ Works | Via xHCI |
| Sleep/Wake | ❌ Unreliable | Historically broken on 6,1 |
| Fan Control | ✅ Works | Via applesmc + macfanctld |
| Temperature Sensors | ✅ Works | Via applesmc + hwmon |

## Known Issues

### Thunderbolt Display Log Spam
The 6,1 generates excessive kernel log messages related to Thunderbolt hotplug detection and ACPI errors with Thunderbolt displays connected. Mitigations:

- `CONFIG_DYNAMIC_DEBUG=y` — selectively silence at runtime
- `acpi_osi=Darwin` boot parameter — may calm firmware re-enumeration
- DSDT override — suppress spurious ACPI events
- `kernel.printk = 3 4 1 3` — reduce console noise
- Patches in `patches/` directory (when available)

### GPU Ring Timeouts Under Sustained Load
Running heavy GPU compute (e.g., LLM inference) on the D700s can cause ring timeout errors and system crashes. The custom kernel with built-in amdgpu driver and correct firmware may improve stability.

### Sleep/Wake
Historically unreliable on the Mac Pro 6,1 under Linux. Not a priority for this kernel build. If you need the machine to sleep, this may not be solved.

## Model Variants

| Model | CPU | GPU | RAM |
|-------|-----|-----|-----|
| Base | E5-1620 v2 (4C/8T, 3.7GHz) | 2x D300 (2GB) | 12GB |
| Mid | E5-1650 v2 (6C/12T, 3.5GHz) | 2x D500 (3GB) | 16GB |
| High | E5-1680 v2 (8C/16T, 3.0GHz) | 2x D700 (6GB) | 32/64GB |
| BTO Max | E5-2697 v2 (12C/24T, 2.7GHz) | 2x D700 (6GB) | 64GB |

The kernel config includes firmware for all GPU variants: Tahiti (D500/D700) and Pitcairn (D300). No changes needed regardless of which model you have.

## PCI Device IDs

```
GPU 1:    1002:6798 (AMD Tahiti XT [FirePro D700])
GPU 2:    1002:6798 (AMD Tahiti XT [FirePro D700])
Audio 1:  1002:aac8 (AMD HDMI Audio)
Audio 2:  1002:aac8 (AMD HDMI Audio)
NIC:      14e4:16b4 (Broadcom BCM57762)
TB:       8086:156c (Intel DSL5520 Thunderbolt)
USB:      8086:1e31 (Intel xHCI)
HDA:      8086:1e20 (Intel HDA)
SSD:      144d:* or similar (varies by SSD)
```

Use `lspci -nn` on your system to verify.
