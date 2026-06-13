# Knowledge Base

This directory contains reference material for AI — patterns, platform notes, and examples of previously grown modules.

**These files are NOT executed on devices.** They exist so that AI (whether running on a host PC or accessed via network) can consult prior experience when generating new code for a specific target.

## Structure

```
knowledge/
  patterns/       general LLVM IR patterns (UART I/O, interrupt vectors, allocators, etc.)
  platforms/      platform-specific notes (memory maps, register addresses, boot sequences)
  examples/       previously grown modules that worked on real hardware
```

## Usage

- In **constrained mode**: the host AI reads these files to inform code generation for the target MCU.
- In **full mode**: once a device has network, its AI can fetch these files from GitHub as reference.

The content here is "experience" — not packages to install, but knowledge to adapt.
