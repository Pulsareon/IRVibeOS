# Tier 1 — Connected Device Seed (ESP32, WiFi MCU)
# 第一级 — 联网设备种子（ESP32，WiFi MCU）

Status / 状态: **planned, not yet implemented / 已规划，尚未实现**

## Concept / 概念

The tier1 seed targets devices with networking (WiFi/BLE) but limited compute (no local LLVM toolchain, no local AI). The device connects directly to a cloud AI service.

Tier1 种子面向有网络能力（WiFi/BLE）但算力有限（无法本地跑 LLVM 工具链或 AI）的设备。设备直连云端 AI 服务。

## Architecture / 架构

### Two Operating Modes / 两种操作模式

**Mode A: Host-driven vibe / 上位机驱动的 vibe**
- Host PC runs `ai_host.py vibe <intent>`
- AI generates IR on host, compiles to Xtensa/RISC-V on host
- Host sends native code via TALK protocol
- Device executes received code
- **Used for**: bootstrapping, development, constrained devices
- **用于**：引导启动、开发、受限设备

**Mode B: Device-driven vibe (autonomous) / 设备驱动的 vibe（自主）**
- Device loads `vibe_engine.ll` (from `src_ir/vibe_engine.ll`)
- Device accepts user intent via serial/display/web
- Device calls AI API over WiFi/TLS
- **AI generates base64-encoded machine code** (Xtensa or RISC-V) directly
  - ESP32 cannot run compiler locally (only 520KB SRAM)
  - AI is instructed to generate ready-to-execute binary
- Device decodes base64 and loads into executable memory
- Device executes the generated code
- **Used for**: deployed/autonomous operation after bootstrap
- **用于**：引导后的部署/自主运行

**Exception to IR-first architecture**: Tier1 is the only tier where AI generates machine code instead of IR, because the device lacks resources to run a compiler.

**IR 优先架构的例外**：Tier1 是唯一让 AI 生成机器码而非 IR 的层级，因为设备缺乏运行编译器的资源。

```
seed.ll (IR, ~300 lines / 约 300 行):
  - Boot + WiFi connect (calls platform externals)
    启动 + WiFi 连接（调用平台外部函数）
  - Load vibe_engine.ll via TALK (from host, once)
    通过 TALK 加载 vibe_engine.ll（从上位机，一次）
  - Jump to vibe_loop() → device becomes autonomous
    跳转到 vibe_loop() → 设备变为自主模式

vibe_engine.ll (from src_ir/, ~400 lines / 来自 src_ir/，约 400 行):
  - Vibe loop: read intent, call AI API with target arch
    Vibe 循环：读取意图、携带目标架构调用 AI API
  - AI generates base64-encoded machine code directly
    AI 直接生成 base64 编码的机器码
  - Decode base64 → load into executable memory → execute
    解码 base64 → 加载到可执行内存 → 执行

Platform externals (provided by IDF/SDK, linked as .a):
平台外部函数（由 IDF/SDK 提供，以 .a 链接）:
  - wifi_connect(ssid, pass) -> status
  - http_post(url, headers, body, resp_buf, resp_size) -> status
  - base64_decode(src, src_len, dst, dst_size) -> len
  - alloc_exec(size) -> ptr
  - free_exec(ptr)
  - display_text(text) / read_line(buf, size) -> len
```

WiFi/HTTP/TLS is **platform infrastructure** (like UART for tier0), not something the seed implements in IR.

WiFi/HTTP/TLS 是**平台基础设施**（类似 tier0 的 UART），不是种子用 IR 实现的东西。

## Code Generation / 代码生成

ESP32 cannot run LLVM toolchain locally (520KB SRAM). Solution:

ESP32 无法在本地运行 LLVM 工具链（只有 520KB SRAM）。方案：

**AI generates machine code directly** — The AI model is prompted with the target architecture ("xtensa-esp32" or "riscv32-esp32c3") and generates base64-encoded executable machine code in its response. No separate compilation step needed.

**AI 直接生成机器码** — AI 模型获得目标架构提示（"xtensa-esp32" 或 "riscv32-esp32c3"）并在响应中生成 base64 编码的可执行机器码。无需单独的编译步骤。

Expected AI response format:
```json
{
  "binary": "<base64-encoded machine code>",
  "entry_offset": 0
}
```

Device extracts the `binary` field, decodes base64, and executes.

## Blockers / 阻塞项

- Need to decide target: ESP32-C3 (RISC-V) or ESP32-S3 (Xtensa)
  需要确定目标：ESP32-C3（RISC-V）或 ESP32-S3（Xtensa）
- Need ESP-IDF build integration for linking platform libs with IR seed
  需要 ESP-IDF 构建集成，将平台库与 IR 种子链接
- TLS requires mbedTLS linked from IDF
  TLS 需要从 IDF 链接 mbedTLS
