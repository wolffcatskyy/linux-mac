# ChatGPT Kernel Debug Prompt

Copy-paste this when stuck on custom kernel issues for Mac Pro 6,1:

---

I'm building a custom Linux kernel for a Mac Pro 6,1 (Late 2013, "trash can"). Help me debug boot/display/driver issues.

## Hardware
- CPU: Intel Xeon E5-1650 v2 (Ivy Bridge-EP), 6c/12t
- GPU: 2x AMD FirePro D700 (Tahiti XT, GCN 1.0 / Southern Islands, PCI ID 1002:6798)
- Network: Broadcom BCM57762 (tg3 driver)
- Display: Thunderbolt 2 / Mini DisplayPort only (no HDMI/DVI)
- EFI: Apple 64-bit UEFI 1.10 (NOT standard PC UEFI)
- Boot: systemd-boot, EFI System Partition at /boot/efi/
- Root: /dev/sda2, Arch Linux

## Kernel Source
- Vanilla kernel 6.19 from kernel.org (no Arch patches)
- Config based on stock Arch /proc/config.gz with minimal changes

## Working Boot Parameters
```
root=/dev/sda2 rw quiet amdgpu.si_support=1 radeon.si_support=0 amdgpu.dc=0 video=efifb:off amdgpu.lockup_timeout=120000,600000,600000,600000 amdgpu.gpu_recovery=1 amdgpu.job_hang_limit=16 pcie_aspm=off amdgpu.dpm=0 acpi_mask_gpe=0x10000 acpi_enforce_resources=lax
```

## Known Constraints
1. **kexec is BROKEN** on Apple EFI — GPU cannot reinitialize without cold boot. Always use systemd-boot + reboot.
2. **Kernel version must match initramfs modules** — vermagic mismatch = no modules load = black screen. Use `mkinitcpio -k VERSION` after `make modules_install`.
3. **amdgpu.si_support=1** is required — D700 is Southern Islands (si), NOT Sea Islands (cik).
4. **amdgpu.dc=0** required — Display Core doesn't work with SI GPUs.
5. **Firmware blobs** (tahiti_*.bin) must either be in initramfs OR embedded via CONFIG_EXTRA_FIRMWARE if amdgpu is built-in.
6. All display outputs go through Thunderbolt 2 — there is no direct HDMI/DVI.

## Current Status
[DESCRIBE YOUR CURRENT ISSUE HERE]

## What I've Tried
[LIST WHAT YOU'VE ALREADY TRIED]
