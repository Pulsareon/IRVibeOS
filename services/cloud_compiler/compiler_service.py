"""
IRVibeOS Cloud Compiler Service
IRVibeOS 云编译服务

Compiles LLVM IR to native code for resource-constrained devices.
为资源受限设备将 LLVM IR 编译为原生代码。
"""

from flask import Flask, request, jsonify
import subprocess
import base64
import tempfile
import os
import hashlib
from datetime import datetime

app = Flask(__name__)

# Target architecture mapping / 目标架构映射
TARGET_MAP = {
    'xtensa-esp32': 'xtensa',
    'riscv32-esp32c3': 'riscv32',
    'thumbv7em-none-eabi': 'thumbv7em',
    'x86_64': 'x86-64',
    'aarch64': 'aarch64'
}

# Security limits / 安全限制
MAX_IR_SIZE = 64 * 1024  # 64KB
MAX_OUTPUT_SIZE = 1 * 1024 * 1024  # 1MB
COMPILE_TIMEOUT = 10  # seconds / 秒

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint / 健康检查端点"""
    return jsonify({'status': 'ok', 'service': 'irvibeos-compiler'})

@app.route('/targets', methods=['GET'])
def list_targets():
    """List supported target architectures / 列出支持的目标架构"""
    return jsonify({
        'targets': list(TARGET_MAP.keys()),
        'description': {
            'xtensa-esp32': 'ESP32-S3 (Xtensa LX7)',
            'riscv32-esp32c3': 'ESP32-C3 (RISC-V)',
            'thumbv7em-none-eabi': 'ARM Cortex-M4/M7',
            'x86_64': 'x86-64 (PC, testing)',
            'aarch64': 'ARM64 (Raspberry Pi, Apple Silicon)'
        }
    })

@app.route('/compile', methods=['POST'])
def compile_ir():
    """
    Compile LLVM IR to native code / 将 LLVM IR 编译为原生代码

    Request body / 请求正文:
    {
        "target": "xtensa-esp32",
        "ir": "define i32 @main() { ret i32 42 }"
    }

    Response / 响应:
    {
        "binary": "<base64-encoded>",
        "size": 1234,
        "hash": "sha256..."
    }
    """
    start_time = datetime.now()

    # Parse request / 解析请求
    if not request.is_json:
        return jsonify({'error': 'Content-Type must be application/json'}), 400

    data = request.json
    target = data.get('target')
    ir_text = data.get('ir')

    # Validate input / 验证输入
    if not target:
        return jsonify({'error': 'Missing "target" field'}), 400

    if not ir_text:
        return jsonify({'error': 'Missing "ir" field'}), 400

    if target not in TARGET_MAP:
        return jsonify({
            'error': f'Unsupported target: {target}',
            'supported': list(TARGET_MAP.keys())
        }), 400

    if len(ir_text) > MAX_IR_SIZE:
        return jsonify({
            'error': f'IR too large: {len(ir_text)} bytes (max {MAX_IR_SIZE})'
        }), 400

    # Compile in temporary directory / 在临时目录中编译
    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            ir_path = os.path.join(tmpdir, 'input.ll')
            obj_path = os.path.join(tmpdir, 'output.o')

            # Write IR to file / 写入 IR 到文件
            with open(ir_path, 'w', encoding='utf-8') as f:
                f.write(ir_text)

            # Run llc with security limits / 运行 llc 带安全限制
            triple = TARGET_MAP[target]
            result = subprocess.run(
                ['llc', '-mtriple', triple, '-filetype=obj', '-o', obj_path, ir_path],
                capture_output=True,
                timeout=COMPILE_TIMEOUT,
                text=True
            )

            if result.returncode != 0:
                return jsonify({
                    'error': 'Compilation failed',
                    'stderr': result.stderr,
                    'stdout': result.stdout
                }), 400

            # Check output size / 检查输出大小
            if not os.path.exists(obj_path):
                return jsonify({'error': 'Compiler did not produce output file'}), 500

            size = os.path.getsize(obj_path)
            if size > MAX_OUTPUT_SIZE:
                return jsonify({
                    'error': f'Output too large: {size} bytes (max {MAX_OUTPUT_SIZE})'
                }), 400

            # Read and encode binary / 读取并编码二进制
            with open(obj_path, 'rb') as f:
                binary_data = f.read()

            binary_b64 = base64.b64encode(binary_data).decode('ascii')
            binary_hash = hashlib.sha256(binary_data).hexdigest()

            # Calculate compilation time / 计算编译时间
            compile_time_ms = int((datetime.now() - start_time).total_seconds() * 1000)

            return jsonify({
                'binary': binary_b64,
                'size': size,
                'hash': binary_hash,
                'target': target,
                'compile_time_ms': compile_time_ms
            })

    except subprocess.TimeoutExpired:
        return jsonify({
            'error': f'Compilation timeout (>{COMPILE_TIMEOUT}s)'
        }), 408

    except Exception as e:
        return jsonify({
            'error': 'Internal server error',
            'details': str(e)
        }), 500

@app.route('/', methods=['GET'])
def index():
    """Service information / 服务信息"""
    return jsonify({
        'service': 'IRVibeOS Cloud Compiler',
        'version': '1.0',
        'endpoints': {
            '/health': 'GET - Health check',
            '/targets': 'GET - List supported targets',
            '/compile': 'POST - Compile LLVM IR to native code'
        },
        'docs': 'https://github.com/Pulsareon/IRVibeOS/tree/main/services/cloud_compiler'
    })

if __name__ == '__main__':
    # Development server / 开发服务器
    # For production, use gunicorn or similar WSGI server
    # 生产环境请使用 gunicorn 或类似的 WSGI 服务器
    app.run(host='0.0.0.0', port=8080, debug=False)
