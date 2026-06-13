FROM llvmorg/llvm:17

# Install Python and dependencies / 安装 Python 和依赖
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory / 设置工作目录
WORKDIR /app

# Copy requirements / 复制依赖文件
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy service code / 复制服务代码
COPY compiler_service.py .

# Expose port / 暴露端口
EXPOSE 8080

# Run service / 运行服务
CMD ["python3", "compiler_service.py"]
