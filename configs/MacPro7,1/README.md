# Mac Pro 7,1 (2019) — "Cheese Grater Redux"

> **Status: Template — needs real hardware testing**
>
> This configuration is based on Apple's published specs and community knowledge.
> It has NOT been validated on actual hardware. If you have a Mac Pro 7,1,
> please test and submit corrections via PR.

## Hardware Specifications

| Component | Details | Kernel Driver | Config Option |
|-----------|---------|--------------|---------------|
| **CPU** | Intel Xeon W-3200 series (Cascade Lake-SP): 8 to 28 cores | — | `CONFIG_NR_CPUS=56` |
| **GPU (stock)** | Radeon Pro 580X (Polaris 20, 8GB) | `amdgpu` | `CONFIG_DRM_AMDGPU=y` |
| **GPU (options)** | Radeon Pro Vega II (Duo), Radeon Pro W5500X/W5700X, Radeon Pro W6800X/W6900X | `amdgpu` | See GPU section below |
| **Ethernet** | 2x 10GbE Broadcom BCM57416 (NBASE-T) | `bnxt_en` | `CONFIG_BNXT=y` |
| **Wi-Fi** | Broadcom BCM4364 802.11ac (Wi-Fi 5) + Bluetooth 5.0 | `brcmfmac` | `CONFIG_BRCMFMAC=m` |
| **Audio** | Intel HDA + Cirrus Logic (likely CS4208 or similar) | `snd_hda_intel` | `CONFIG_SND_HDA_INTEL=y`, `CONFIG_SND_HDA_CODEC_CIRRUS=y` |
| **Storage** | 2x internal M.2 NVMe slots (T2-managed in macOS) | `nvme` | `CONFIG_BLK_DEV_NVME=y` |
| **Thunderbolt** | 4x Thunderbolt 3 ports (Intel JHL7540 / Titan Ridge) | `thunderbolt` | `CONFIG_THUNDERBOLT=y` |
| **USB** | 2x USB-A 3.0 (internal), USB-C via Thunderbolt | `xhci_hcd` | `CONFIG_USB_XHCI_HCD=y` |
| **T2 Security Chip** | Apple T2 (controls SSD, audio, more) | See T2 section | See T2 section |
| **Thermal** | Apple SMC | `applesmc` | `CONFIG_SENSORS_APPLESMC=y` |
| **Boot** | EFI (64-bit, UEFI 2.x via T2) | — | `CONFIG_EFI=y`, `CONFIG_EFI_STUB=y` |

## GPU Details

All Mac Pro 7,1 GPUs are AMD — no Nvidia options. The range spans three AMD generations:

### GPU Options (All AMD)

| GPU | Architecture | VRAM | Driver | Firmware Prefix |
|-----|-------------|------|--------|----------------|
| Radeon Pro 580X | Polaris 20 (GCN 4) | 8GB | `amdgpu` | `amdgpu/polaris10_*` |
| Radeon Pro Vega II | Vega 20 (GCN 5.1) | 32GB HBM2 | `amdgpu` | `amdgpu/vega20_*` |
| Radeon Pro Vega II Duo | 2x Vega 20 (GCN 5.1) | 2x 32GB HBM2 | `amdgpu` | `amdgpu/vega20_*` |
| Radeon Pro W5500X | Navi 14 (RDNA 1) | 8GB | `amdgpu` | `amdgpu/navi14_*` |
| Radeon Pro W5700X | Navi 10 (RDNA 1) | 16GB | `amdgpu` | `amdgpu/navi10_*` |
| Radeon Pro W6800X | Navi 21 (RDNA 2) | 32GB | `amdgpu` | `amdgpu/sienna_cichlid_*` |
| Radeon Pro W6900X | Navi 21 (RDNA 2) | 32GB | `amdgpu` | `amdgpu/sienna_cichlid_*` |
| Radeon Pro W6800X Duo | 2x Navi 21 (RDNA 2) | 2x 32GB | `amdgpu` | `amdgpu/sienna_cichlid_*` |

**Note:** The kernel config should enable support for all AMD GPU generations (Polaris through RDNA 2) since different 7,1 configurations ship with different GPUs. Users can trim to their specific GPU after testing.

### Afterburner Card

Some 7,1 configurations include the Apple Afterburner card — an FPGA-based ProRes/ProRes RAW accelerator. There is currently no Linux driver for Afterburner. It will appear in `lspci` but won't be functional.

## T2 Security Chip Considerations

The Mac Pro 7,1 includes Apple's T2 chip, which mediates several hardware functions:

| Function | Impact on Linux | Mitigation |
|----------|----------------|------------|
| **SSD Controller** | T2 encrypts NVMe storage by default | Disable FileVault in macOS before installing Linux, or use external NVMe |
| **Audio** | T2 routes audio on some Macs | May need `apple-t2-audio-config` or `snd_hda_macbookpro` patches |
| **Secure Boot** | T2 validates boot chain | Set Startup Security to "No Security" in Recovery Mode |
| **Touch ID** | Fingerprint sensor | Not usable in Linux |

**Recommendation:** Before installing Linux, boot into macOS Recovery and:
1. Set Startup Security Utility to "No Security"
2. Allow booting from external media
3. Disable FileVault if using internal NVMe

See [t2linux.org](https://t2linux.org) for community T2 Linux support.

## Hardware Compatibility Matrix

| Feature | Status | Notes |
|---------|--------|-------|
| Display (DP) | 🔲 Untested | Via amdgpu + DC |
| Display (HDMI) | 🔲 Untested | Via HDMI 2.0 on MPX Module |
| Display (TB) | 🔲 Untested | Via Thunderbolt 3 |
| OpenGL | 🔲 Untested | Mesa radeonsi |
| Vulkan | 🔲 Untested | Mesa RADV |
| GPU Compute | 🔲 Untested | ROCm support depends on GPU generation |
| 10GbE Ethernet | 🔲 Untested | Broadcom bnxt_en driver |
| Wi-Fi | 🔲 Untested | BCM4364 requires proprietary firmware |
| Bluetooth | 🔲 Untested | Via T2 chip — may be problematic |
| Audio (3.5mm) | 🔲 Untested | May require T2 audio patches |
| Audio (HDMI/DP) | 🔲 Untested | Via amdgpu HDMI audio |
| Thunderbolt 3 | 🔲 Untested | 4 ports via Titan Ridge |
| USB 3.0 | 🔲 Untested | 2x USB-A + USB-C via TB |
| Internal NVMe | 🔲 Untested | T2-managed, may need encryption disabled |
| External NVMe | 🔲 Untested | Via PCIe or Thunderbolt — no T2 issues |
| Sleep/Wake | ❓ Unknown | T2 complicates power management |
| Fan Control | 🔲 Untested | Via applesmc — multiple fans |
| Temperature Sensors | 🔲 Untested | Via applesmc + hwmon |
| Afterburner | ❌ No driver | FPGA card — no Linux support |

## Known Considerations

### T2 Chip
The T2 chip is the biggest difference from older Mac Pros. It affects boot security, storage encryption, and audio routing. See the T2 section above and [t2linux.org](https://t2linux.org) for details.

### 10GbE Networking
The 7,1 has dual 10GbE (Broadcom BCM57416 using the `bnxt_en` driver). This is a different driver family from the `tg3` used in the 5,1 and 6,1. The sysctl config includes tuning for 10GbE throughput.

### MPX Module GPU Format
The 7,1 uses Apple's proprietary MPX Module form factor for GPUs, which combines a standard PCIe GPU with a Thunderbolt bridge. The GPU itself uses standard PCIe and works with standard amdgpu drivers — the MPX connector just adds Thunderbolt passthrough for displays.

### Massive RAM Support
The 7,1 supports up to 1.5TB of DDR4 ECC RAM across 12 DIMM slots. The kernel config and sysctl are tuned for large memory configurations.

## Model Variants

| Model | CPU | Cores/Threads | GPU (base) | RAM Slots |
|-------|-----|--------------|------------|-----------|
| Base | W-3223 (8C/16T, 3.5GHz) | 8C/16T | Radeon Pro 580X (8GB) | 12 |
| Mid | W-3245 (16C/32T, 3.2GHz) | 16C/32T | Radeon Pro 580X (8GB) | 12 |
| High | W-3265M (24C/48T, 2.7GHz) | 24C/48T | Radeon Pro 580X (8GB) | 12 |
| Max | W-3275M (28C/56T, 2.5GHz) | 28C/56T | Radeon Pro 580X (8GB) | 12 |

All models can be configured with any of the GPU options listed above. Dual-GPU MPX modules (Vega II Duo, W6800X Duo) occupy both MPX bays.

**Note:** RAM is DDR4 ECC (2933MHz). 12 DIMM slots. Apple officially supports up to 1.5TB (12x 128GB), though configurations above 768GB were BTO only.

## PCI Device IDs (Base Configuration)

```
GPU:        1002:7310 or similar (AMD Polaris/Vega/Navi — varies by config)
NIC 1:      14e4:16d7 (Broadcom BCM57416 10GbE)
NIC 2:      14e4:16d7 (Broadcom BCM57416 10GbE)
Wi-Fi:      14e4:4464 (Broadcom BCM4364)
TB 1:       8086:15eb (Intel JHL7540 Titan Ridge)
TB 2:       8086:15eb (Intel JHL7540 Titan Ridge)
USB:        8086:* (Intel xHCI)
HDA:        8086:* (Intel HDA controller)
T2:         106b:* (Apple T2 coprocessor)
NVMe:       106b:* (Apple/T2 NVMe controller)
```

**Note:** PCI IDs vary significantly based on GPU configuration. Use `lspci -nn` on your system to verify.
