# Cloud Compiler Service
# 云编译服务

**Language / 语言**: [English](#english) | [中文](#中文)

---

## English

### Purpose

The Cloud Compiler Service compiles LLVM IR to native code for resource-constrained devices (tier1: ESP32, embedded ARM) that cannot run LLVM toolchain locally. This enables device-driven vibe on networked MCUs.

### Architecture

```
Device → HTTP POST /compile
         {target, ir_text}
         ↓
Cloud Service:
  1. Validate IR syntax
  2. Run llc in sandboxed container
  3. Return native binary or error
         ↓
Device ← HTTP 200 {binary: base64}
      or HTTP 400 {error: "..."}
```

### API Endpoint

**POST /compile**

Request body (JSON):
```json
{
  "target": "xtensa-esp32",
  "ir": "define i32 @main() {\n  ret i32 42\n}"
}
```

Supported targets:
- `xtensa-esp32` — ESP32-S3 (Xtensa LX7)
- `riscv32-esp32c3` — ESP32-C3 (RISC-V)
- `thumbv7em-none-eabi` — ARM Cortex-M4/M7
- `x86_64` — PC (for testing)

Response (success, 200):
```json
{
  "binary": "<base64-encoded native code>",
  "size": 1234
}
```

Response (error, 400):
```json
{
  "error": "llc: <stderr output>"
}
```

### Implementation

**Option 1: Self-hosted (recommended for development)**

Use Docker + Flask/FastAPI:

```dockerfile
FROM llvmorg/llvm:17
RUN apt-get update && apt-get install -y python3-pip
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY compiler_service.py .
EXPOSE 8080
CMD ["python3", "compiler_service.py"]
```

```python
from flask import Flask, request, jsonify
import subprocess, base64, tempfile, os

app = Flask(__name__)

TARGET_MAP = {
    'xtensa-esp32': 'xtensa',
    'riscv32-esp32c3': 'riscv32',
    'thumbv7em-none-eabi': 'thumbv7em',
    'x86_64': 'x86-64'
}

@app.route('/compile', methods=['POST'])
def compile_ir():
    data = request.json
    target = data.get('target')
    ir_text = data.get('ir')
    
    if not target or not ir_text:
        return jsonify({'error': 'Missing target or ir'}), 400
    
    if target not in TARGET_MAP:
        return jsonify({'error': f'Unsupported target: {target}'}), 400
    
    with tempfile.TemporaryDirectory() as tmpdir:
        ir_path = os.path.join(tmpdir, 'input.ll')
        obj_path = os.path.join(tmpdir, 'output.o')
        
        with open(ir_path, 'w') as f:
            f.write(ir_text)
        
        # Compile with timeout and resource limits
        result = subprocess.run(
            ['llc', '-mtriple', TARGET_MAP[target], 
             '-filetype=obj', '-o', obj_path, ir_path],
            capture_output=True,
            timeout=10,
            text=True
        )
        
        if result.returncode != 0:
            return jsonify({'error': result.stderr}), 400
        
        with open(obj_path, 'rb') as f:
            binary = base64.b64encode(f.read()).decode()
        
        size = os.path.getsize(obj_path)
        return jsonify({'binary': binary, 'size': size})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

**Option 2: Serverless (AWS Lambda, Google Cloud Functions)**

Package LLVM + function code, deploy as serverless endpoint. Good for scale but cold start latency.

**Option 3: Public service**

Community-hosted compilation service (like godbolt.org but API-only). Security critical: sandboxing, rate limits, resource quotas.

### Security

- **Sandboxing**: Run llc in isolated container (gVisor, Firecracker)
- **Resource limits**: CPU time < 10s, memory < 512MB, output size < 1MB
- **Rate limiting**: Per-IP rate limit (10 req/min)
- **Input validation**: Check IR size < 64KB, reject shell metacharacters in target string
- **No network access** from compilation sandbox

### Deployment

**Self-hosted example** (single-command):
```bash
docker build -t irvibeos-compiler .
docker run -p 8080:8080 irvibeos-compiler
```

Configure device to use: `http://your-server:8080/compile`

**Cloud deployment** (AWS ECS, Google Cloud Run, Azure Container Instances):
- Auto-scaling based on request volume
- HTTPS endpoint with API key authentication
- Logging and monitoring for compilation failures

### Testing

```bash
curl -X POST http://localhost:8080/compile \
  -H "Content-Type: application/json" \
  -d '{
    "target": "x86_64",
    "ir": "define i32 @main() {\n  ret i32 42\n}"
  }'
```

Expected output:
```json
{
  "binary": "H4sIAAAAAAAAA...",
  "size": 856
}
```

---

## 中文

### 用途

云编译服务为资源受限的设备（tier1：ESP32，嵌入式 ARM）将 LLVM IR 编译为原生代码，这些设备无法在本地运行 LLVM 工具链。这使联网 MCU 能实现设备驱动的 vibe。

### 架构

```
设备 → HTTP POST /compile
       {target, ir_text}
       ↓
云服务：
  1. 验证 IR 语法
  2. 在沙箱容器中运行 llc
  3. 返回原生二进制或错误
       ↓
设备 ← HTTP 200 {binary: base64}
    或 HTTP 400 {error: "..."}
```

### API 端点

**POST /compile**

请求正文（JSON）：
```json
{
  "target": "xtensa-esp32",
  "ir": "define i32 @main() {\n  ret i32 42\n}"
}
```

支持的目标：
- `xtensa-esp32` — ESP32-S3（Xtensa LX7）
- `riscv32-esp32c3` — ESP32-C3（RISC-V）
- `thumbv7em-none-eabi` — ARM Cortex-M4/M7
- `x86_64` — PC（用于测试）

响应（成功，200）：
```json
{
  "binary": "<base64 编码的原生代码>",
  "size": 1234
}
```

响应（错误，400）：
```json
{
  "error": "llc: <stderr 输出>"
}
```

### 实现

**选项 1：自托管（推荐用于开发）**

使用 Docker + Flask/FastAPI：

```dockerfile
FROM llvmorg/llvm:17
RUN apt-get update && apt-get install -y python3-pip
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY compiler_service.py .
EXPOSE 8080
CMD ["python3", "compiler_service.py"]
```

Python 代码见上方英文部分。

**选项 2：无服务器（AWS Lambda、Google Cloud Functions）**

打包 LLVM + 函数代码，部署为无服务器端点。适合扩展但有冷启动延迟。

**选项 3：公共服务**

社区托管的编译服务（类似 godbolt.org 但纯 API）。安全至关重要：沙箱、速率限制、资源配额。

### 安全

- **沙箱化**：在隔离容器中运行 llc（gVisor、Firecracker）
- **资源限制**：CPU 时间 < 10s，内存 < 512MB，输出大小 < 1MB
- **速率限制**：每 IP 速率限制（10 请求/分钟）
- **输入验证**：检查 IR 大小 < 64KB，拒绝 target 字符串中的 shell 元字符
- **无网络访问**：编译沙箱不可访问网络

### 部署

**自托管示例**（单命令）：
```bash
docker build -t irvibeos-compiler .
docker run -p 8080:8080 irvibeos-compiler
```

配置设备使用：`http://your-server:8080/compile`

**云部署**（AWS ECS、Google Cloud Run、Azure Container Instances）：
- 根据请求量自动扩展
- HTTPS 端点带 API 密钥认证
- 记录和监控编译失败

### 测试

```bash
curl -X POST http://localhost:8080/compile \
  -H "Content-Type: application/json" \
  -d '{
    "target": "x86_64",
    "ir": "define i32 @main() {\n  ret i32 42\n}"
  }'
```

预期输出：
```json
{
  "binary": "H4sIAAAAAAAAA...",
  "size": 856
}
```
