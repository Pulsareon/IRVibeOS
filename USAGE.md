# IRVibeOS 使用指南

## 快速开始

### 1. 验证所有IR源文件

```powershell
.\tools\verify.ps1
```

检查所有.ll文件的语法正确性，包括字符串常量长度和SSA规则。

### 2. 编译所有模块

```powershell
# 清理并编译 (x86_64)
.\tools\build.ps1 -Clean

# 详细输出模式
.\tools\build.ps1 -Verbose

# 编译ARM Cortex-M目标
.\tools\build.ps1 -Target "thumbv7m-none-eabi" -OutputDir "build_arm" -Clean
```

输出：build/ 目录下的 .o 目标文件

### 3. 创建自己的IR模块

在 `modules/你的项目/` 下创建 `.ll` 文件：

```llvm
; 示例：modules/test/my_first.ll
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

@.greeting = private constant [26 x i8] c"Hello from my IR module!\0A\00"

declare i32 @printf(ptr, ...)

define i32 @main() {
entry:
  %result = call i32 @printf(ptr @.greeting)
  ret i32 0
}
```

### 4. 编译你的模块

```powershell
# 编译为目标文件
llc -mtriple=x86_64-pc-windows-msvc -filetype=obj modules\test\my_first.ll -o build\my_first.o

# 链接生成可执行文件
clang build\my_first.o -o build\my_first.exe

# 运行
.\build\my_first.exe
```

### 5. 编译其他架构

```powershell
# ARM Cortex-M (Tier0 MCU)
llc -mtriple=thumbv7m-none-eabi -filetype=obj seed\tier0_mcu\seed.ll -o build\seed_arm.o

# RISC-V
llc -mtriple=riscv32 -filetype=obj modules\hello\main.ll -o build\hello_riscv.o
```

## 项目结构

```
IRVibeOS/
├── src_ir/              # 核心系统IR源码
│   ├── irvibeos.ll      # OS原语
│   └── vibe_engine.ll   # AI驱动引擎
├── seed/                # 各层级引导程序
│   ├── tier0_mcu/       # MCU引导 (UART/TALK协议)
│   └── tier3_hosted/    # 托管环境引导
├── modules/             # 功能模块
│   └── hello/           # Hello模块示例
├── examples/            # 示例代码
├── knowledge/           # 知识库
│   ├── patterns/        # 编码模式
│   └── examples/        # 参考示例
├── tools/               # 开发工具
│   ├── build.ps1        # 构建工具
│   └── verify.ps1       # 验证工具
└── build/               # 编译输出 (git ignored)
```

## 设备层级系统

### Tier 0 - MCU (资源受限)
- **设备**: ATmega328P, STM32F103
- **传输**: UART (9600-115200 baud)
- **协议**: TALK (文本格式)
- **生成**: 主机编译，通过TALK发送二进制
- **引导**: `seed/tier0_mcu/seed.ll`

### Tier 1 - ESP32 (内存<1MB)
- **设备**: ESP32, ESP8266
- **传输**: WiFi
- **生成**: AI直接生成机器码
- **例外**: IR-first架构的唯一例外

### Tier 2 - UEFI (现代启动)
- **设备**: 现代PC UEFI固件
- **生成**: AI生成IR，设备本地编译
- **引导**: `seed/tier2_uefi/seed.ll` (待实现)

### Tier 3 - 托管环境
- **设备**: Windows/Linux/macOS
- **生成**: AI生成IR，本地编译
- **引导**: `seed/tier3_hosted/seed.ll`

## 常见问题

### Q: 字符串常量长度不匹配错误？
```
error: constant expression type mismatch: got type '[26 x i8]' but expected '[27 x i8]'
```

**解决**: 手动计算字符串实际字节数，包括 `\0A`(1字节), `\00`(1字节)：
```llvm
; "Hello\n\0" = 5 + 1 + 1 = 7字节
@msg = private constant [7 x i8] c"Hello\0A\00"
```

### Q: SSA违规错误？
```
Instruction does not dominate all uses!
```

**解决**: 使用phi节点合并来自不同分支的值：
```llvm
branch1:
  %value1 = add i32 %a, 1
  br label %merge

branch2:
  %value2 = add i32 %a, 2
  br label %merge

merge:
  %result = phi i32 [ %value1, %branch1 ], [ %value2, %branch2 ]
```

### Q: 函数指针调用错误？
```
error: expected value token
```

**解决**: 函数指针调用不需要 `ptr` 关键字：
```llvm
; 错误
%result = call i32 ptr @my_func()

; 正确
%result = call i32 @my_func()
```

## 下一步

1. **阅读架构文档**: `PROJECT_STATUS.md`
2. **学习IR编写**: `knowledge/examples/` 和 `knowledge/patterns/`
3. **实现Tier1引导**: `seed/tier1_esp32/seed.ll` (ESP32 WiFi)
4. **实现Tier2引导**: `seed/tier2_uefi/seed.ll` (UEFI固件)
5. **开发更多模块**: 在 `modules/` 添加你的功能

## 工具参考

### build.ps1 参数

```powershell
-Target <string>      # 目标架构 (默认: x86_64-pc-windows-msvc)
-OutputDir <string>   # 输出目录 (默认: build)
-Clean                # 清理构建目录
-Verbose              # 显示详细编译过程
```

### verify.ps1

无参数，自动发现并验证所有 .ll 文件。

## 贡献

欢迎提交PR：
1. 修复编译错误
2. 添加新模块
3. 实现缺失的seed引导
4. 改进工具链

---

**IR-First 架构**: 所有源码都是LLVM IR，除了Tier1设备（内存限制）
