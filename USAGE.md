# IRVibeOS 1.0 Hosted 使用指南

当前 1.0 版本聚焦 hosted 模式：在已有 Windows/Linux/macOS 上运行 LLVM 工具链，用意图生成 LLVM IR 模块，验证后保存到 `modules/` 并运行。

## 1. 环境要求

- LLVM 工具：`llvm-as`、`llc`、`lli`
- Python 3
- 可选：使用 AI provider 时安装 `requests`

检查工具：

```powershell
Get-Command llvm-as, llc, lli, python
```

## 2. 验证项目

```powershell
.\tools\verify.ps1
```

该脚本会：

- 自动发现仓库中的 `.ll` 文件。
- 排除 `build/`、`build_arm/`、`data/`、`target/`、`temp/`。
- 使用 `llvm-as` 做真实 IR 语法验证。
- 检查 `modules/*` 是否具备 `main.ll` 和 `deps.txt`。

## 3. 构建全部 IR

```powershell
.\tools\build.ps1 -Clean
```

指定目标：

```powershell
.\tools\build.ps1 -Target "thumbv7m-none-eabi" -OutputDir "build_arm" -Clean
```

`build.ps1` 会自动发现全部 `.ll` 文件，并把对象文件输出到指定目录。

## 4. 运行 hosted shell

列出模块：

```powershell
lli src_ir\irvibeos.ll apps
```

运行模块：

```powershell
"hello" | lli src_ir\irvibeos.ll run
"test" | lli src_ir\irvibeos.ll run
"testmod" | lli src_ir\irvibeos.ll run
```

从 IR shell 触发验证：

```powershell
lli src_ir\irvibeos.ll verify
```

## 5. 从意图生成模块

离线模板模式：

```powershell
python host\hosted_vibe.py --name demo --intent "print a hello message" --provider template --run
```

这会生成：

```text
modules/demo/main.ll
modules/demo/deps.txt
```

并用 `llvm-as` 验证生成的 IR。加上 `--run` 会使用 `lli` 立即运行模块。

OpenAI 兼容 API 示例：

```powershell
python host\hosted_vibe.py `
  --name ai_demo `
  --intent "print three short lines about LLVM IR" `
  --provider openai-compatible `
  --api-base http://localhost:11434/v1 `
  --api-key dummy `
  --model llama3 `
  --run
```

OpenAI 示例：

```powershell
$env:OPENAI_API_KEY="sk-..."
$env:IRVIBEOS_MODEL="<model-name>"
python host\hosted_vibe.py --name openai_demo --intent "print hello from IR" --provider openai --run
```

Claude 示例：

```powershell
$env:ANTHROPIC_API_KEY="sk-ant-..."
$env:IRVIBEOS_MODEL="<model-name>"
python host\hosted_vibe.py --name claude_demo --intent "print hello from IR" --provider claude --run
```

覆盖已存在模块：

```powershell
python host\hosted_vibe.py --name demo --intent "print a new message" --provider template --force --run
```

## 6. 模块规范

每个 hosted 模块必须是：

```text
modules/<name>/
  main.ll
  deps.txt
```

`main.ll` 必须有：

```llvm
define i32 @main()
```

简单示例：

```llvm
; IRVibeOS module example.

@msg = private unnamed_addr constant [10 x i8] c"hello IR\0A\00"

declare i32 @puts(ptr)

define i32 @main() {
entry:
  call i32 @puts(ptr @msg)
  ret i32 0
}
```

## 7. 当前限制

- `host/hosted_vibe.py` 是 1.0 推荐入口。
- `host/ai_host.py` 仍是 TALK seed 实验工具，EXEC payload 格式尚未稳定。
- `src_ir/vibe_engine.ll` 仍是设备端路线图，API 请求构造和响应解析尚未完成。
- Tier1 ESP32 与 Tier2 UEFI seed 尚未实现。

## 8. 适合贡献的方向

1. 改进 `hosted_vibe.py` 的上下文选择和 IR 修复提示。
2. 增加更多 `modules/` 示例。
3. 为模块增加更丰富的 manifest。
4. 定义 TALK EXEC 的真正 payload 格式。
5. 实现 `vibe_engine.ll` 的 JSON/API 解析。
