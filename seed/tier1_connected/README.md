# Tier 1 — Connected Device Seed (ESP32, WiFi MCU)
# 第一级 — 联网设备种子（ESP32，WiFi MCU）

Status / 状态: **planned, not yet implemented / 已规划，尚未实现**

## Concept / 概念

The tier1 seed targets devices with networking (WiFi/BLE) but limited compute (no local LLVM toolchain, no local AI). The device connects directly to a cloud AI service.

Tier1 种子面向有网络能力（WiFi/BLE）但算力有限（无法本地跑 LLVM 工具链或 AI）的设备。设备直连云端 AI 服务。

## Architecture / 架构

```
seed.ll (IR, ~500 lines / 约 500 行):
  - Boot + WiFi connect (calls platform externals)
    启动 + WiFi 连接（调用平台外部函数）
  - TCP/TLS socket to AI endpoint
    TCP/TLS 连接到 AI 端点
  - Vibe loop: send intent, receive IR, load + execute
    Vibe 循环：发送意图、接收 IR、加载并执行

Platform externals (provided by IDF/SDK, linked as .a):
平台外部函数（由 IDF/SDK 提供，以 .a 链接）:
  - wifi_connect(ssid, pass) -> status
  - tcp_connect(host, port) -> socket
  - tls_handshake(socket, hostname) -> status
  - tcp_send / tcp_recv / tcp_close
```

WiFi/TCP/TLS is **platform infrastructure** (like UART for tier0), not something the seed implements in IR.

WiFi/TCP/TLS 是**平台基础设施**（类似 tier0 的 UART），不是种子用 IR 实现的东西。

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
