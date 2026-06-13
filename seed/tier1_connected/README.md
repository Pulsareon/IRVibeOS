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
- AI returns IR text to device
- Device sends IR to **cloud compilation service**
- Service compiles IR → Xtensa/RISC-V binary, returns to device
- Device loads and executes compiled code
- **Used for**: deployed/autonomous operation after bootstrap
- **用于**：引导后的部署/自主运行

```
seed.ll (IR, ~300 lines / 约 300 行):
  - Boot + WiFi connect (calls platform externals)
    启动 + WiFi 连接（调用平台外部函数）
  - Load vibe_engine.ll via TALK (from host, once)
    通过 TALK 加载 vibe_engine.ll（从上位机，一次）
  - Jump to vibe_loop() → device becomes autonomous
    跳转到 vibe_loop() → 设备变为自主模式

vibe_engine.ll (from src_ir/, ~400 lines / 来自 src_ir/，约 400 行):
  - Vibe loop: read intent, call AI API, receive IR
    Vibe 循环：读取意图、调用 AI API、接收 IR
  - Send IR to cloud compiler, receive native binary
    发送 IR 到云编译器，接收原生二进制
  - Load + execute generated code
    加载并执行生成的代码

Platform externals (provided by IDF/SDK, linked as .a):
平台外部函数（由 IDF/SDK 提供，以 .a 链接）:
  - wifi_connect(ssid, pass) -> status
  - http_post(url, headers, body, resp_buf, resp_size) -> status
  - alloc_exec(size) -> ptr
  - free_exec(ptr)
  - display_text(text) / read_line(buf, size) -> len
```

WiFi/HTTP/TLS is **platform infrastructure** (like UART for tier0), not something the seed implements in IR. The cloud compilation service endpoint is configurable.

WiFi/HTTP/TLS 是**平台基础设施**（类似 tier0 的 UART），不是种子用 IR 实现的东西。云编译服务端点可配置。

## Compilation Problem / 编译问题

ESP32 cannot run `clang`/`llc` locally (520KB SRAM). Options:

ESP32 无法在本地运行 `clang`/`llc`（只有 520KB SRAM）。方案：

1. Cloud compilation: device sends IR text → cloud returns native binary
   云编译：设备发送 IR 文本 → 云端返回原生二进制
2. Pre-compiled modules: AI generates IR, build server compiles, OTA push
   预编译模块：AI 生成 IR，构建服务器编译，OTA 推送

## Blockers / 阻塞项

- Need to decide target: ESP32-C3 (RISC-V) or ESP32-S3 (Xtensa)
  需要确定目标：ESP32-C3（RISC-V）或 ESP32-S3（Xtensa）
- Need ESP-IDF build integration for linking platform libs with IR seed
  需要 ESP-IDF 构建集成，将平台库与 IR 种子链接
- TLS requires mbedTLS linked from IDF
  TLS 需要从 IDF 链接 mbedTLS
