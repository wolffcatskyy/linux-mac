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

The Linux driver stack is **9 years newer** than what OCLP shims. Kernel 6.19 alone brings 25-40% improvements for GCN 1.0 GPUs.

**Caveat:** The PVG command format between the guest driver and host framework is proprietary and undocumented. Building this pipeline requires reverse-engineering that protocol. The transport layer (how data moves) is documented in QEMU. The translation layer (what the GPU commands mean) is not. See "What's Known vs What's a Black Box" below.

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

### QEMU's apple-gfx-pci (GPL, public)

Phil Dennis-Jordan's patches (16 revisions, merged into QEMU) implement the PCI device that bridges guest and host:

- **PCI device:** Single memory-mapped BAR
- **MMIO registers:** Command/status interface
- **Interrupt delivery:** Guest notification mechanism
- **Shared memory:** Callbacks for alloc/map/unmap/dealloc
- **Display surface:** Framebuffer presentation path

Source: `https://gitlab.com/qemu-project/qemu/-/tree/master/hw/display/`

Key files:
- `apple-gfx-pci.m` — PCI device registration, BAR setup, MMIO
- `apple-gfx.m` — Host-side integration with Apple's framework (Objective-C)
- `apple-gfx.h` — Shared structures and constants

### macOS PVG Guest Driver (ships with macOS 11+)

Apple includes paravirtualized graphics drivers in macOS. These are used for macOS VMs on Apple Silicon but also work on x86_64 when the `apple-gfx-pci` device is present. **No custom kext installation needed.**

### What's Known vs What's a Black Box

This is important to be honest about.

**Phil's QEMU code documents the plumbing** — PCI device setup, MMIO register layout, shared memory lifecycle, interrupt delivery, and framebuffer presentation. This is the transport layer.

**Apple's `ParavirtualizedGraphics.framework` is a black box.** Phil described it himself: *"Data is exchanged via an undocumented, Apple-proprietary protocol. The PVG API only acts as a facilitator."* His QEMU code hands off opaque data to Apple's framework. The actual GPU command buffer format — how Metal commands are serialized over the wire, how textures/shaders/pipelines are encoded — is inside the framework, not in the QEMU source.

This means:
- ✅ We know how to set up the device and move data between guest and host
- ✅ We know the display surface path (how rendered frames are presented)
- ✅ We know shared memory management (alloc/map/unmap/dealloc)
- ❌ We don't know the GPU command serialization format
- ❌ We don't know the detailed semantics of the command stream

### What's Missing

To build a Linux PVG host, we need two things:

1. **The transport layer (known):** Receive data from the QEMU device, manage shared memory, present display surfaces, deliver interrupts. Phil's code documents this.

2. **The translation layer (unknown):** Decode the GPU command stream that macOS sends, translate it to Mesa/Vulkan/OpenGL calls, execute on the host GPU. This requires reverse-engineering Apple's proprietary protocol.

The translation layer is the hard part. But it's not impossible — see the approach below.

## Protocol Analysis (from QEMU source)

What the QEMU source reveals about the transport layer:

### Memory Management (documented)
- `PVGMemoryMap` — Guest requests shared memory mapping
- `PVGMemoryUnmap` — Guest releases mapping
- Host manages a pool of shared buffers accessible to both guest and host GPU

### Display Path (documented)
- Guest renders to a surface
- Host presents the surface (blit to screen or compose with other windows)
- MMIO-based signaling for vsync/flip

### Synchronization (documented)
- Interrupt delivery for host → guest notification
- MMIO polling/registers for guest → host signaling

### Command Submission (black box)
- Guest submits GPU command buffers via shared memory
- Commands are Metal-encoded on the guest side
- **The format of these commands is proprietary and undocumented**
- On macOS hosts, Apple's framework decodes them — on Linux, we'd need to reverse-engineer this

## Approaches to Reverse-Engineering the Command Format

### Traffic Capture
Run a macOS VM on a **macOS host** (where Apple's framework works), instrument Phil's QEMU device to log every MMIO write and shared memory operation. Run known Metal workloads, capture what goes over the wire. Correlate inputs with observed GPU behavior.

### Guest Driver Analysis
The PVG guest drivers ship with macOS. Static analysis of the guest-side kext could reveal the serialization format from the sender's perspective.

### Incremental Approach
The macOS WindowServer/compositor likely uses a simpler subset of the protocol than full Metal apps. If we can crack just the 2D compositing commands, the desktop gets fast even if arbitrary Metal apps don't work yet. This is the most practical early target.

## Implementation Phases

### Phase A: Protocol Documentation
- Document everything Phil's QEMU code reveals about the transport layer
- Map every MMIO register, callback, shared memory operation
- Produce a standalone transport specification
- **No code needed — pure documentation**

### Phase B: Traffic Capture & Analysis
- Run macOS VM on macOS host with instrumented QEMU device
- Log all MMIO writes, shared memory operations, interrupt patterns
- Run known Metal workloads (simple clear, textured quad, compositor)
- Build a corpus of captured protocol traffic
- Begin identifying patterns in the command stream

### Phase C: Transport Layer Implementation
- Implement the Linux-side transport: PCI device setup, shared memory, interrupts
- Accept memory mappings, acknowledge device initialization
- Forward display surfaces to host display (framebuffer only)
- Proves the communication path works end-to-end on Linux
- **Delivers value immediately:** faster framebuffer presentation via host GPU

### Phase D: Compositor Acceleration
- Focus on reverse-engineering WindowServer/compositor commands
- The compositor likely uses a smaller, simpler subset of the protocol
- Implement just enough translation to accelerate desktop compositing
- macOS desktop becomes smooth even without full Metal support
- **This is the realistic near-term goal**

### Phase E: Broader Metal Support (long-term)
- Progressively decode more of the command buffer format
- Translate Metal commands to Vulkan via Mesa RADV
- Full 3D app support is the end goal but may take significant effort
- Could be accelerated if Apple ever documents the protocol or someone reverse-engineers the framework

### Phase F: Optimization
- Reduce host ↔ guest copies
- Zero-copy shared memory where possible
- Batch command submission
- Async presentation pipeline

## Why This Is Tractable (with caveats)

**What's straightforward:**
1. **Transport layer is documented** — Phil's QEMU code shows device setup, shared memory, interrupts, and display surfaces. Reimplementing this on Linux is well-scoped engineering.
2. **Guest side is done** — macOS ships the drivers. No custom kext needed.
3. **Display path acceleration is achievable** — Even without understanding GPU commands, faster framebuffer presentation through the host GPU delivers real improvement.

**What's hard:**
1. **GPU command format is proprietary** — Apple's `ParavirtualizedGraphics.framework` is a black box. The actual command serialization format is undocumented.
2. **Reverse-engineering takes time** — Traffic capture and analysis is the path, but it's iterative and slow.
3. **Full Metal translation is ambitious** — Going from proprietary Metal command buffers to Vulkan/OpenGL is a significant reverse-engineering effort.

**Why it's still worth pursuing:**
- Each phase delivers value independently. Phase C (transport + display) improves macOS VM experience without solving the command format.
- The compositor subset is likely much simpler than full Metal. Cracking that alone makes the desktop fast.
- This is the kind of problem that attracts smart contributors once there's a working foundation to build on.
- If Apple ever opens PVG (unlikely but not impossible) or someone reverse-engineers the framework, the transport layer is ready.

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
