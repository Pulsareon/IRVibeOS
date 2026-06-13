; IRVibeOS Vibe Engine — on-device AI-powered code generation
; IRVibeOS Vibe 引擎 — 设备端 AI 驱动的代码生成
;
; This module enables a networked device to vibe directly:
; 本模块让联网设备可以直接 vibe：
;   1. Accept intent from user / 从用户接收意图
;   2. Send intent + target arch to AI API / 发送意图 + 目标架构到 AI API
;   3. AI generates ready-to-execute code for target / AI 生成目标架构的可执行代码
;      - Tier1 (ESP32): AI generates Xtensa/RISC-V machine code (base64)
;      - Tier2 (PC): AI generates x86-64 machine code or IR (if llc available)
;   4. Decode and load the binary / 解码并加载二进制
;   5. Execute / 执行
;
; NO cloud compilation service needed - AI generates the final binary directly
; 无需云编译服务 - AI 直接生成最终二进制
;
; Platform dependencies (provided externally):
; 平台依赖（外部提供）:
;   Network: @http_post(url, headers, body, resp_buf, resp_size) -> status
;   Memory: @alloc_exec(size) -> ptr, @free_exec(ptr)
;   Display: @display_text(text)
;   Input: @read_line(buf, size) -> len
;   Decoding: @base64_decode(src, src_len, dst, dst_size) -> len

; External platform functions / 外部平台函数
declare i32 @http_post(ptr, ptr, ptr, ptr, i32)  ; url, headers, body, resp_buf, resp_size -> status
declare ptr @alloc_exec(i32)                      ; size -> executable memory
declare void @free_exec(ptr)
declare void @display_text(ptr)
declare i32 @read_line(ptr, i32)                  ; buf, size -> length
declare i32 @base64_decode(ptr, i32, ptr, i32)    ; src, src_len, dst, dst_size -> decoded_len
declare i32 @json_extract_string(ptr, ptr, ptr, i32)  ; json, key, out_buf, out_size -> len

; Global configuration / 全局配置
@ai_provider = global i32 0     ; 0=unset, 1=openai, 2=claude, 3=openai-compatible
@api_key = global [256 x i8] zeroinitializer
@api_base = global [256 x i8] zeroinitializer
@model_name = global [64 x i8] zeroinitializer
@target_arch = global [32 x i8] zeroinitializer    ; Target architecture (e.g., "xtensa", "x86-64") / 目标架构

; String constants / 字符串常量
@prompt_str = private constant [20 x i8] c"irvibeos vibe> \00\00\00\00\00"
@intent_prompt = private constant [18 x i8] c"Enter intent: \00\00\00\00"
@generating_msg = private constant [29 x i8] c"Calling AI, please wait...\0A\00"
@loading_msg = private constant [18 x i8] c"Loading code...\0A\00"
@executing_msg = private constant [15 x i8] c"Executing...\0A\00"
@done_msg = private constant [10 x i8] c"Done.\0A\00\00\00\00"
@error_msg = private constant [25 x i8] c"Vibe failed. Check AI.\0A\00"

@openai_url = private constant [45 x i8] c"https://api.openai.com/v1/chat/completions\00\00"
@claude_url = private constant [42 x i8] c"https://api.anthropic.com/v1/messages\00\00\00\00\00"

@system_prompt = private constant [512 x i8] c"You are a code generator for IRVibeOS running on %s architecture. Generate EXECUTABLE MACHINE CODE (base64-encoded) that implements the user's intent. Output ONLY a JSON response: {\"binary\":\"<base64>\",\"entry_offset\":0}. The binary must be position-independent and ready to execute. Start with a function prologue, implement the logic, end with ret. No markdown, no explanations, just the JSON.\00\00\00\00\00\00\00"

; Vibe main entry / Vibe 主入口
define i32 @vibe_loop() {
entry:
  %intent_buf = alloca [1024 x i8]
  %resp_buf = alloca [16384 x i8]
  %native_buf = alloca [8192 x i8]

  br label %loop

loop:
  ; Display prompt / 显示提示符
  call void @display_text(ptr @intent_prompt)

  ; Read user intent / 读取用户意图
  %intent_len = call i32 @read_line(ptr %intent_buf, i32 1024)
  %has_input = icmp sgt i32 %intent_len, 0
  br i1 %has_input, label %process, label %loop

process:
  ; Show progress / 显示进度
  call void @display_text(ptr @generating_msg)

  ; Call AI to generate executable binary / 调用 AI 生成可执行二进制
  %provider = load i32, ptr @ai_provider
  %binary_b64_len = call i32 @call_ai(i32 %provider, ptr %intent_buf, i32 %intent_len, ptr %resp_buf, i32 16384)
  %ai_ok = icmp sgt i32 %binary_b64_len, 0
  br i1 %ai_ok, label %decode, label %error

decode:
  ; Decode base64 binary from AI response / 从 AI 响应解码 base64 二进制
  call void @display_text(ptr @loading_msg)
  %native_len = call i32 @base64_decode(ptr %resp_buf, i32 %binary_b64_len, ptr %native_buf, i32 8192)
  %decode_ok = icmp sgt i32 %native_len, 0
  br i1 %decode_ok, label %execute, label %error

execute:
  ; Allocate executable memory / 分配可执行内存
  %exec_mem = call ptr @alloc_exec(i32 %native_len)
  %exec_ok = icmp ne ptr %exec_mem, null
  br i1 %exec_ok, label %copy_and_run, label %error

copy_and_run:
  ; Copy native code to executable memory / 拷贝原生代码到可执行内存
  call void @memcpy(ptr %exec_mem, ptr %native_buf, i32 %native_len)

  ; Execute / 执行
  call void @display_text(ptr @executing_msg)
  %result = call i32 ptr %exec_mem()

  ; Cleanup / 清理
  call void @free_exec(ptr %exec_mem)
  call void @display_text(ptr @done_msg)
  br label %loop

error:
  call void @display_text(ptr @error_msg)
  br label %loop
}

; Call AI API (dispatcher) / 调用 AI API（分派器）
define i32 @call_ai(i32 %provider, ptr %intent, i32 %intent_len, ptr %out_buf, i32 %out_size) {
entry:
  switch i32 %provider, label %unsupported [
    i32 1, label %openai
    i32 2, label %claude
    i32 3, label %openai_compat
  ]

openai:
  %len_openai = call i32 @call_openai_api(ptr %intent, i32 %intent_len, ptr %out_buf, i32 %out_size)
  ret i32 %len_openai

claude:
  %len_claude = call i32 @call_claude_api(ptr %intent, i32 %intent_len, ptr %out_buf, i32 %out_size)
  ret i32 %len_claude

openai_compat:
  %len_compat = call i32 @call_openai_compatible_api(ptr %intent, i32 %intent_len, ptr %out_buf, i32 %out_size)
  ret i32 %len_compat

unsupported:
  ret i32 -1
}

; Call OpenAI API / 调用 OpenAI API
define i32 @call_openai_api(ptr %intent, i32 %intent_len, ptr %out_buf, i32 %out_size) {
entry:
  %headers_buf = alloca [512 x i8]
  %body_buf = alloca [2048 x i8]

  ; Build headers / 构建请求头
  call void @build_openai_headers(ptr %headers_buf)

  ; Build JSON body / 构建 JSON 正文
  call void @build_openai_body(ptr %intent, i32 %intent_len, ptr %body_buf)

  ; HTTP POST / HTTP 发送
  %status = call i32 @http_post(ptr @openai_url, ptr %headers_buf, ptr %body_buf, ptr %out_buf, i32 %out_size)
  %ok = icmp eq i32 %status, 200
  br i1 %ok, label %extract, label %fail

extract:
  ; Extract base64-encoded binary from JSON response / 从 JSON 响应提取 base64 编码的二进制
  %binary_len = call i32 @extract_binary_from_openai_response(ptr %out_buf, i32 %out_size)
  ret i32 %binary_len

fail:
  ret i32 -1
}

; Call Claude API / 调用 Claude API
define i32 @call_claude_api(ptr %intent, i32 %intent_len, ptr %out_buf, i32 %out_size) {
entry:
  %headers_buf = alloca [512 x i8]
  %body_buf = alloca [2048 x i8]

  call void @build_claude_headers(ptr %headers_buf)
  call void @build_claude_body(ptr %intent, i32 %intent_len, ptr %body_buf)

  %status = call i32 @http_post(ptr @claude_url, ptr %headers_buf, ptr %body_buf, ptr %out_buf, i32 %out_size)
  %ok = icmp eq i32 %status, 200
  br i1 %ok, label %extract, label %fail

extract:
  %binary_len = call i32 @extract_binary_from_claude_response(ptr %out_buf, i32 %out_size)
  ret i32 %binary_len

fail:
  ret i32 -1
}

; Call OpenAI-compatible API / 调用 OpenAI 兼容 API
define i32 @call_openai_compatible_api(ptr %intent, i32 %intent_len, ptr %out_buf, i32 %out_size) {
entry:
  ; Use custom api_base / 使用自定义 api_base
  %headers_buf = alloca [512 x i8]
  %body_buf = alloca [2048 x i8]

  call void @build_openai_headers(ptr %headers_buf)
  call void @build_openai_body(ptr %intent, i32 %intent_len, ptr %body_buf)

  %status = call i32 @http_post(ptr @api_base, ptr %headers_buf, ptr %body_buf, ptr %out_buf, i32 %out_size)
  %ok = icmp eq i32 %status, 200
  br i1 %ok, label %extract, label %fail

extract:
  %binary_len = call i32 @extract_binary_from_openai_response(ptr %out_buf, i32 %out_size)
  ret i32 %binary_len

fail:
  ret i32 -1
}

; Stub implementations for header/body builders and response parsers
; These would be fully implemented with JSON formatting and parsing
; 头部/正文构建器和响应解析器的桩实现
; 实际应完整实现 JSON 格式化和解析

define void @build_openai_headers(ptr %buf) {
  ; TODO: sprintf(buf, "Authorization: Bearer %s\nContent-Type: application/json\n", api_key)
  ret void
}

define void @build_claude_headers(ptr %buf) {
  ; TODO: sprintf(buf, "x-api-key: %s\nanthropic-version: 2023-06-01\nContent-Type: application/json\n", api_key)
  ret void
}

define void @build_openai_body(ptr %intent, i32 %len, ptr %buf) {
  ; TODO: build JSON with target architecture in system prompt
  ; {"model":"...","messages":[
  ;   {"role":"system","content":"Generate base64 machine code for <target_arch>..."},
  ;   {"role":"user","content":"<intent>"}
  ; ]}
  ret void
}

define void @build_claude_body(ptr %intent, i32 %len, ptr %buf) {
  ; TODO: build JSON with target architecture in system prompt
  ; {"model":"...","max_tokens":8192,"system":"Generate base64 machine code for <target_arch>...",
  ;  "messages":[{"role":"user","content":"<intent>"}]}
  ret void
}

define i32 @extract_binary_from_openai_response(ptr %json, i32 %len) {
  ; TODO: parse JSON response
  ; Expected format: {"choices":[{"message":{"content":"{\"binary\":\"<base64>\"}"}}]}
  ; Extract the binary field from the nested JSON, move to start of buffer, return length
  ret i32 0
}

define i32 @extract_binary_from_claude_response(ptr %json, i32 %len) {
  ; TODO: parse JSON response
  ; Expected format: {"content":[{"text":"{\"binary\":\"<base64>\"}"}]}
  ; Extract the binary field from the nested JSON, move to start of buffer, return length
  ret i32 0
}

; Helper: memcpy / 辅助函数：内存拷贝
define void @memcpy(ptr %dst, ptr %src, i32 %len) {
entry:
  %cmp = icmp ugt i32 %len, 0
  br i1 %cmp, label %loop, label %done

loop:
  %i = phi i32 [0, %entry], [%next, %loop]
  %sp = getelementptr i8, ptr %src, i32 %i
  %dp = getelementptr i8, ptr %dst, i32 %i
  %byte = load i8, ptr %sp
  store i8 %byte, ptr %dp
  %next = add i32 %i, 1
  %more = icmp ult i32 %next, %len
  br i1 %more, label %loop, label %done

done:
  ret void
}

; Configuration helpers / 配置辅助函数
define void @set_ai_provider(i32 %provider) {
  store i32 %provider, ptr @ai_provider
  ret void
}

define void @set_api_key(ptr %key) {
  call void @strcpy(ptr @api_key, ptr %key)
  ret void
}

define void @set_api_base(ptr %base) {
  call void @strcpy(ptr @api_base, ptr %base)
  ret void
}

define void @strcpy(ptr %dst, ptr %src) {
entry:
  br label %loop

loop:
  %i = phi i32 [0, %entry], [%next, %loop]
  %sp = getelementptr i8, ptr %src, i32 %i
  %dp = getelementptr i8, ptr %dst, i32 %i
  %ch = load i8, ptr %sp
  store i8 %ch, ptr %dp
  %is_null = icmp eq i8 %ch, 0
  %next = add i32 %i, 1
  br i1 %is_null, label %done, label %loop

done:
  ret void
}

define void @set_compiler_url(ptr %url) {
  call void @strcpy(ptr @compiler_url, ptr %url)
  ret void
}

define void @set_target_arch(ptr %arch) {
  call void @strcpy(ptr @target_arch, ptr %arch)
  ret void
}

; Cloud compilation wrapper / 云编译包装器
; For tier1 devices: sends IR to cloud service
; For tier2 devices: can call local llc instead
; tier1 设备：将 IR 发送到云服务
; tier2 设备：可改为调用本地 llc
define i32 @compile_ir_cloud(ptr %ir_text, i32 %ir_len, ptr %out_buf, i32 %out_size) {
entry:
  %json_buf = alloca [32768 x i8]
  %resp_buf = alloca [65536 x i8]

  ; Build JSON request: {"target":"<arch>","ir":"<ir_text>"}
  ; 构建 JSON 请求：{"target":"<arch>","ir":"<ir_text>"}
  ; Note: This is simplified - production needs proper JSON string escaping
  ; 注意：这是简化版 - 生产需要适当的 JSON 字符串转义
  call void @build_compile_request(ptr @target_arch, ptr %ir_text, i32 %ir_len, ptr %json_buf, i32 32768)

  ; HTTP POST to cloud compiler / HTTP POST 到云编译器
  %status = call i32 @http_post(ptr @compiler_url, ptr @compile_json_headers, ptr %json_buf, ptr %resp_buf, i32 65536)
  %ok = icmp eq i32 %status, 200
  br i1 %ok, label %parse, label %fail

parse:
  ; Extract binary field from JSON and decode base64
  ; 从 JSON 提取 binary 字段并解码 base64
  %len = call i32 @extract_and_decode_binary(ptr %resp_buf, ptr %out_buf, i32 %out_size)
  ret i32 %len

fail:
  ret i32 -1
}

@compile_json_headers = private constant [50 x i8] c"Content-Type: application/json\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00"

; Stub implementations for JSON building and parsing
; These require full implementation with proper escaping and parsing
; JSON 构建和解析的桩实现
; 需要完整实现适当的转义和解析

define void @build_compile_request(ptr %target, ptr %ir, i32 %ir_len, ptr %out, i32 %out_size) {
  ; TODO: sprintf(out, "{\"target\":\"%s\",\"ir\":\"%s\"}", target, json_escape(ir))
  ret void
}

define i32 @extract_and_decode_binary(ptr %json_resp, ptr %out, i32 %out_size) {
  ; TODO: parse JSON, extract .binary field, base64_decode it
  ; 解析 JSON，提取 .binary 字段，base64 解码
  ret i32 0
}
