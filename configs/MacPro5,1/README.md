# Mac Pro 5,1 (Mid 2010 / Mid 2012) — "Cheese Grater"

> **Status: Template — needs real hardware testing**
>
> This configuration is based on Apple's published specs and community knowledge.
> It has NOT been validated on actual hardware. If you have a Mac Pro 5,1,
> please test and submit corrections via PR.

## Hardware Specifications

| Component | Details | Kernel Driver | Config Option |
|-----------|---------|--------------|---------------|
| **CPU** | Single/Dual Intel Xeon (Westmere-EP): W3530, W3680, X5650, X5690, etc. | — | `CONFIG_NR_CPUS=24` |
| **GPU (stock)** | ATI Radeon HD 5770 (1GB) or HD 5870 (1GB) — Evergreen/Northern Islands | `radeon` or `amdgpu` | `CONFIG_DRM_RADEON=y` or `CONFIG_DRM_AMDGPU=y` + `CONFIG_DRM_AMDGPU_SI=y` |
| **GPU (common upgrades)** | AMD RX 580, RX Vega 56/64, Nvidia GTX 680/780 (Kepler) | `amdgpu` / `nouveau` | See GPU section below |
| **Ethernet** | Broadcom BCM57762 Dual Gigabit | `tg3` | `CONFIG_TIGON3=y` |
| **Wi-Fi** | None stock (many add BCM94360CD via PCIe) | `brcmfmac`/`b43` | `CONFIG_BRCMFMAC=m` |
| **Audio** | Intel HDA + Cirrus Logic CS4206 | `snd_hda_intel` | `CONFIG_SND_HDA_INTEL=y`, `CONFIG_SND_HDA_CODEC_CIRRUS=y` |
| **Storage** | 4x 3.5" SATA bays (ICH10 AHCI), 2x internal SATA (optical) | `ahci` | `CONFIG_SATA_AHCI=y` |
| **Storage (upgraded)** | NVMe via PCIe adapter (common upgrade) | `nvme` | `CONFIG_BLK_DEV_NVME=y` |
| **FireWire** | 4x FireWire 800 (LSI FW643) | `firewire-ohci` | `CONFIG_FIREWIRE=y`, `CONFIG_FIREWIRE_OHCI=y` |
| **Thunderbolt** | None | — | — |
| **USB** | 5x USB 2.0 (EHCI/UHCI) | `ehci_hcd`/`uhci_hcd` | `CONFIG_USB_EHCI_HCD=y` |
| **Thermal** | Apple SMC | `applesmc` | `CONFIG_SENSORS_APPLESMC=y` |
| **Boot** | EFI (32-bit EFI on 2010 models, 64-bit on 2012 models) | — | `CONFIG_EFI=y`, `CONFIG_EFI_STUB=y`, `CONFIG_EFI_MIXED=y` |

## GPU Details

The Mac Pro 5,1 has a unique GPU situation — most owners have upgraded from the stock Radeon HD 5770/5870 to more modern cards. The kernel config must accommodate this.

### Stock GPUs

- **Radeon HD 5770** — Juniper XT (Evergreen, VLIW5)
- **Radeon HD 5870** — Cypress XT (Evergreen, VLIW5)
- Driver: `radeon` (legacy) or `amdgpu` with SI support
- Firmware: `radeon/JUNIPER_*.bin` or `radeon/CYPRESS_*.bin`

### Common GPU Upgrades

| GPU | Architecture | Driver | Firmware | Notes |
|-----|-------------|--------|----------|-------|
| AMD RX 580 | Polaris 20 (GCN 4) | `amdgpu` | `amdgpu/polaris10_*.bin` | Metal-capable, most popular upgrade |
| AMD RX Vega 56/64 | Vega 10 (GCN 5) | `amdgpu` | `amdgpu/vega10_*.bin` | High performance |
| AMD Radeon VII | Vega 20 (GCN 5.1) | `amdgpu` | `amdgpu/vega20_*.bin` | Workstation-class |
| Nvidia GTX 680 | Kepler (GK104) | `nouveau` | N/A (open-source) | No macOS Metal support |
| Nvidia GTX 780 | Kepler (GK110) | `nouveau` | N/A (open-source) | No macOS Metal support |

**Recommendation:** The template config enables both `amdgpu` (with SI/CIK/Polaris/Vega support) and `nouveau`. Users should disable whichever they don't need.

### Multi-GPU Configurations

The 5,1 has 4 PCIe slots (2x x16, 1x x4, 1x x1), and multi-GPU setups are common. The kernel config supports multiple simultaneous GPU drivers if needed.

## Hardware Compatibility Matrix

| Feature | Status | Notes |
|---------|--------|-------|
| Display (stock GPU) | 🔲 Untested | HD 5770/5870 via radeon driver |
| Display (AMD upgrade) | 🔲 Untested | RX 580/Vega via amdgpu |
| Display (Nvidia Kepler) | 🔲 Untested | GTX 680/780 via nouveau |
| OpenGL | 🔲 Untested | Mesa radeonsi (AMD) or nouveau (Nvidia) |
| Vulkan | 🔲 Untested | RADV (AMD) — no Vulkan for Kepler |
| Ethernet | 🔲 Untested | Dual GbE via tg3 (same as 6,1) |
| Wi-Fi (added) | 🔲 Untested | BCM94360CD via PCIe if installed |
| Audio (3.5mm) | 🔲 Untested | Intel HDA + Cirrus CS4206 |
| Audio (HDMI/DP) | 🔲 Untested | Via GPU audio |
| FireWire 800 | 🔲 Untested | 4 ports via LSI FW643 |
| USB 2.0 | 🔲 Untested | 5 ports via EHCI |
| USB 3.0 (added) | 🔲 Untested | Via PCIe card if installed |
| SATA (internal bays) | 🔲 Untested | 4x 3.5" + 2x optical via AHCI |
| NVMe (added) | 🔲 Untested | Via PCIe adapter |
| Sleep/Wake | ❓ Unknown | Historically problematic on Mac Pros |
| Fan Control | 🔲 Untested | Via applesmc — different sensor layout than 6,1 |
| Temperature Sensors | 🔲 Untested | Via applesmc + hwmon |

## Known Considerations

### 32-bit EFI (Mid 2010 models)
Early Mac Pro 5,1 (and 4,1 flashed to 5,1) shipped with 32-bit EFI firmware. This requires `CONFIG_EFI_MIXED=y` to boot a 64-bit kernel from 32-bit EFI. The Mid 2012 revision has 64-bit EFI.

### No Thunderbolt
Unlike the 6,1, the 5,1 has no Thunderbolt — it uses FireWire 800 instead. The Thunderbolt kernel options can be disabled unless a Thunderbolt PCIe card has been added.

### CPU Variety
The 5,1 came with a wide range of CPUs, and many owners have upgraded:
- Single-CPU configs: 4-6 cores (W3530, W3680)
- Dual-CPU configs: 8-12 cores (X5650, X5660, X5670, X5680, X5690)
- Max: Dual X5690 = 12 cores / 24 threads

### GPU Power
The PCIe slots provide limited auxiliary power. High-power GPUs (>225W) may need a pixlas mod or external power adapter. The kernel doesn't need to know about this, but it affects which GPUs are practically usable.

## Model Variants

| Model | CPU | GPU (stock) | RAM Max |
|-------|-----|-------------|---------|
| Mid 2010 (single) | W3530 (4C/8T, 2.8GHz) | Radeon HD 5770 (1GB) | 64GB |
| Mid 2010 (single) | W3680 (6C/12T, 3.33GHz) | Radeon HD 5770 (1GB) | 64GB |
| Mid 2010 (dual) | 2x X5650 (12C/24T, 2.66GHz) | Radeon HD 5770 (1GB) | 128GB |
| Mid 2010 (dual) | 2x X5670 (12C/24T, 2.93GHz) | Radeon HD 5870 (1GB) | 128GB |
| Mid 2012 (single) | W3680 (6C/12T, 3.33GHz) | Radeon HD 5770 (1GB) | 64GB |
| Mid 2012 (dual) | 2x X5690 (12C/24T, 3.46GHz) | Radeon HD 5770 (1GB) | 128GB |
| BTO Max | 2x X5690 (12C/24T, 3.46GHz) | Radeon HD 5870 (1GB) | 128GB |

**Note:** RAM is DDR3 ECC. Single CPU configs use 4 DIMM slots (max 64GB), dual CPU configs use 8 DIMM slots (max 128GB with 16GB DIMMs).

## PCI Device IDs (Stock Configuration)

```
GPU:      1002:68b8 (ATI Radeon HD 5770) or 1002:6898 (ATI Radeon HD 5870)
NIC 1:    14e4:16b4 (Broadcom BCM57762)
NIC 2:    14e4:16b4 (Broadcom BCM57762)
FW:       11c1:5901 (LSI FW643 FireWire)
HDA:      8086:3a6e (Intel 82801JI HD Audio)
USB:      8086:3a34/3a35/3a36/3a37/3a38/3a39 (Intel ICH10 EHCI/UHCI)
SATA:     8086:3a22 (Intel ICH10 AHCI)
SMBus:    8086:3a30 (Intel ICH10 SMBus)
```

**Note:** PCI IDs will differ significantly if the GPU has been upgraded. Use `lspci -nn` on your system to verify.
