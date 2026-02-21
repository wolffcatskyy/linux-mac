# pvg-linux: Open-Source Apple ParavirtualizedGraphics Host for Linux

## The Opportunity

QEMU 10.0 introduced `apple-gfx-pci` — a paravirtualized GPU device for macOS guests. macOS 11+ ships built-in PVG (ParavirtualizedGraphics) guest drivers. The **guest side is complete** — no custom kexts needed.

The catch: the host side (`ParavirtualizedGraphics.framework`) only exists on macOS. On a Linux host, there's nothing listening.

**This document proposes building the host side on Linux**, translating PVG commands to Mesa/Vulkan/OpenGL via the host GPU driver. For machines like the Mac Pro 6,1 with AMD GPUs, this means macOS gets GPU acceleration through Linux's actively-maintained amdgpu driver — which has had 9 years of improvements since Apple abandoned these GPUs.

## Why This Matters

### The OCLP Pipeline (bare metal, if/when supported)
```
macOS Metal app → OCLP legacy kext shims → abandoned AMD drivers (2017) → GPU
```

### The PVG Pipeline (this project)
```
macOS Metal app → built-in PVG driver → apple-gfx-pci → Linux PVG host
  → Mesa radeonsi/RADV → amdgpu (kernel 6.19) → GPU
```

The Linux driver stack is **9 years newer** than what OCLP shims. Kernel 6.19 alone brings 25-40% improvements for GCN 1.1 GPUs. This isn't theoretical — the pipeline uses actively maintained, production drivers.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  macOS Guest (KVM)                    │
│                                                       │
│  Metal App → CoreGraphics → PVG Guest Driver (built-in) │
│                          │                            │
│                    ┌─────┴─────┐                      │
│                    │ PCI BAR   │ MMIO + shared memory  │
│                    │ apple-gfx │ MSI interrupts        │
│                    └─────┬─────┘                      │
├──────────────────────────┼────────────────────────────┤
│                    QEMU  │  apple-gfx-pci device      │
├──────────────────────────┼────────────────────────────┤
│              Linux Host  │                            │
│                    ┌─────┴─────┐                      │
│                    │ pvg-linux │ ← THIS PROJECT       │
│                    │  PVG Host │                      │
│                    └─────┬─────┘                      │
│                          │                            │
│                    ┌─────┴─────┐                      │
│                    │   Mesa    │ radeonsi (GL)         │
│                    │   RADV   │ (Vulkan)              │
│                    └─────┬─────┘                      │
│                          │                            │
│                    ┌─────┴─────┐                      │
│                    │  amdgpu   │ kernel 6.19           │
│                    └─────┬─────┘                      │
│                          │                            │
│                    ┌─────┴─────┐                      │
│                    │  D700 GPU │ hardware              │
│                    └───────────┘                      │
└─────────────────────────────────────────────────────┘
```

## What Exists Today

### QEMU 10's apple-gfx-pci (GPL, public)

Phil Dennis-Jordan's patches (14 revisions, merged into QEMU 10) implement the PCI device that bridges guest and host:

- **PCI device:** Single memory-mapped BAR
- **MMIO registers:** Command/status interface
- **MSI interrupts:** Guest notification
- **Shared memory:** Callbacks for alloc/map/unmap/dealloc
- **Display surface:** Framebuffer presentation path

The QEMU source code (`hw/display/apple-gfx*`) is the Rosetta Stone — it documents the entire PVG protocol as implemented by Apple's framework on the host side.

Source: `https://gitlab.com/qemu-project/qemu/-/tree/master/hw/display/`

Key files:
- `apple-gfx-pci.c` — PCI device registration, BAR setup, MMIO
- `apple-gfx.m` — Host-side integration with Apple's framework (Objective-C)
- `apple-gfx.h` — Shared structures and constants

### macOS PVG Guest Driver (ships with macOS 11+)

Apple includes paravirtualized graphics drivers in macOS. These are used for macOS VMs on Apple Silicon but also work on x86_64 when the `apple-gfx-pci` device is present. **No custom kext installation needed.**

### What's Missing

The host-side implementation on Linux. On macOS hosts, QEMU calls into `ParavirtualizedGraphics.framework`. On Linux, we need to:

1. Receive PVG commands from the QEMU device
2. Translate them to Mesa/Vulkan/OpenGL calls
3. Execute on the host GPU via the Linux driver stack
4. Return results (rendered frames, completion signals) to the guest

## Protocol Analysis (from QEMU source)

The PVG protocol, as documented in QEMU 10's apple-gfx implementation:

### Memory Management
- `PVGMemoryMap` — Guest requests shared memory mapping
- `PVGMemoryUnmap` — Guest releases mapping
- Host manages a pool of shared buffers accessible to both guest and host GPU

### Command Submission
- Guest submits GPU command buffers via MMIO writes
- Commands are Metal-encoded on the guest side
- Host must decode and re-encode for its own GPU API

### Display Path
- Guest renders to a surface
- Host presents the surface (blit to screen or compose with other windows)
- MMIO-based signaling for vsync/flip

### Synchronization
- MSI interrupts for host → guest notification
- MMIO polling/registers for guest → host signaling
- Fence objects for GPU command completion

## Implementation Phases

### Phase A: Protocol Documentation
- Read all 14 revisions of Phil Dennis-Jordan's QEMU patches
- Document every MMIO register, every callback, every shared memory operation
- Produce a standalone protocol specification
- **No code needed — pure documentation**

### Phase B: Stub Host Implementation
- Implement a Linux-side PVG host that responds to the protocol
- Accept memory mappings, acknowledge commands
- Return a blank or solid-color framebuffer
- Proves the communication path works end-to-end

### Phase C: Software Renderer
- Decode PVG command buffers
- Execute via llvmpipe (Mesa software renderer)
- Slow but functionally complete
- Guest macOS gets a "GPU" that actually works

### Phase D: Hardware Acceleration
- Replace llvmpipe with radeonsi (OpenGL) or RADV (Vulkan)
- Commands execute on host GPU hardware
- Full Metal support in macOS guest
- This is where "faster than OCLP" becomes real

### Phase E: Optimization
- Reduce host ↔ guest copies
- Zero-copy shared memory where possible
- Batch command submission
- Async presentation pipeline

## Why This Is Tractable

1. **Protocol is documented** — QEMU 10's GPL source code shows exactly how Apple's framework interacts with the PCI device. 14 revisions of public code review means the interface is well-understood.

2. **Guest side is done** — macOS ships the drivers. We don't need to write a kext or hack the guest at all.

3. **Scope is bounded** — We're implementing one side of a documented protocol. The hard research (designing the protocol) was done by Apple and documented by Phil's QEMU patches.

4. **Mesa is the target** — Mesa has extensive documentation, stable APIs, and active maintenance. radeonsi and RADV are mature.

5. **Incremental value** — Each phase delivers something useful. Phase B proves feasibility. Phase C gives functional (slow) GPU. Phase D gives fast GPU.

## Benefits Beyond Mac Pro 6,1

This implementation benefits **every macOS-in-KVM-on-Linux setup**:

- Any Linux host with AMD GPU (radeonsi/RADV)
- Any Linux host with Intel GPU (iris/ANV)
- Any Linux host with NVIDIA GPU (nouveau/NVK, or proprietary)
- Cloud/server environments running macOS VMs on Linux

The Mac Pro 6,1 is the most dramatic showcase (9 years of driver improvements), but the implementation is GPU-agnostic via Mesa.

## Contributing

This is a significant undertaking. The most valuable contributions right now:

1. **Protocol documentation** — Read QEMU 10 source, document the PVG interface
2. **Metal command buffer analysis** — Understanding what the guest sends
3. **Mesa integration expertise** — How to efficiently submit work to radeonsi/RADV
4. **Testing** — Running macOS guests on various Linux + GPU combinations

If you're Phil Dennis-Jordan reading this: your QEMU patches are the foundation this is built on. We'd welcome any guidance, code review, or direct involvement. This is the Linux side of what you already built the bridge for.

## References

- QEMU 10 apple-gfx source: `hw/display/apple-gfx*`
- Phil Dennis-Jordan's patch series: QEMU mailing list archives
- Mesa documentation: https://docs.mesa3d.org/
- amdgpu driver: `drivers/gpu/drm/amd/` in Linux kernel source
- Apple PVG framework headers: Xcode SDK (macOS 11+)
- KVM documentation: https://www.kernel.org/doc/html/latest/virt/kvm/

## License

GPL-2.0-or-later (compatible with QEMU and Linux kernel)
