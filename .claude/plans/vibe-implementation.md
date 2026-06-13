# IRVibeOS真实Vibe功能实现方案

## 目标
实现可实际运行的vibe功能，代码只使用LLVM IR，能调用真实AI API并生成可执行代码。

## 现状分析

### 已有代码
1. **irvibeos.ll** - 基础shell，vibe命令只生成模板
2. **vibe_engine.ll** - 完整架构，但关键函数是桩实现：
   - `@build_openai_headers` - TODO
   - `@build_openai_body` - TODO  
   - `@build_claude_headers` - TODO
   - `@build_claude_body` - TODO
   - `@extract_code_from_openai_response` - TODO
   - `@extract_code_from_claude_response` - TODO

### 外部依赖声明
```llvm
declare i32 @http_post(ptr, ptr, ptr, ptr, i32)
declare i32 @compile_ir_local(ptr, i32, ptr, i32)
declare ptr @alloc_exec(i32)
declare void @display_text(ptr)
declare i32 @read_line(ptr, i32)
declare i32 @base64_decode(ptr, i32, ptr, i32)
```

## 实现策略

### 阶段1：简化版本（托管环境，Tier3）
专注Windows托管环境，使用现有libc/WinAPI实现平台层。

**实现内容**：
1. **platform_windows.ll** - Windows平台支持层
   - `@http_post` - 使用WinHTTP API
   - `@display_text` - 使用printf
   - `@read_line` - 使用fgets
   - `@alloc_exec` - 使用VirtualAlloc
   - `@compile_ir_local` - 调用llc编译器

2. **json_builder.ll** - 纯IR的JSON构建器
   - `@build_openai_headers` - sprintf风格字符串格式化
   - `@build_claude_headers` - sprintf风格字符串格式化
   - `@build_openai_body` - JSON字符串拼接
   - `@build_claude_body` - JSON字符串拼接
   - `@json_escape` - 转义特殊字符

3. **json_parser.ll** - 纯IR的JSON解析器
   - `@extract_code_from_openai_response` - 查找"content"字段
   - `@extract_code_from_claude_response` - 查找"content"字段
   - `@json_find_string_value` - 通用字符串值提取

4. **vibe_demo.ll** - 可运行的完整demo
   - 集成vibe_engine.ll
   - 链接平台层和JSON层
   - 提供命令行接口测试

### 阶段2：完整集成
将简化版本集成回irvibeos.ll主系统。

## 技术细节

### JSON构建示例
```llvm
define void @build_openai_body(i32 %tier, ptr %intent, i32 %len, ptr %buf) {
entry:
  %model = load ptr, ptr @model_name
  %prompt = select i1 %is_tier1, ptr @system_prompt_binary, ptr @system_prompt_ir
  
  ; sprintf(buf, "{\"model\":\"%s\",\"messages\":[{\"role\":\"system\",\"content\":\"%s\"},{\"role\":\"user\",\"content\":\"%s\"}]}", 
  ;         model, prompt, intent)
  call i32 (ptr, ptr, ...) @sprintf(ptr %buf, ptr @json_body_fmt, ptr %model, ptr %prompt, ptr %intent)
  ret void
}
```

### JSON解析示例
```llvm
define i32 @extract_code_from_openai_response(i32 %tier, ptr %json, i32 %len) {
entry:
  ; 查找 "content": "..."
  %content_start = call ptr @strstr(ptr %json, ptr @content_key)
  %has_content = icmp ne ptr %content_start, null
  br i1 %has_content, label %extract, label %fail
  
extract:
  ; 跳过 "content": "
  %value_start = getelementptr i8, ptr %content_start, i32 11
  ; 查找结束引号
  %value_end = call ptr @strchr(ptr %value_start, i32 34)
  ; 计算长度并拷贝
  %code_len = call i32 @extract_json_string(ptr %value_start, ptr %value_end, ptr %json)
  ret i32 %code_len
  
fail:
  ret i32 -1
}
```

### HTTP实现（Windows）
```llvm
; 使用WinHTTP API
declare ptr @WinHttpOpen(ptr, i32, ptr, ptr, i32)
declare ptr @WinHttpConnect(ptr, ptr, i32, i32)
declare ptr @WinHttpOpenRequest(ptr, ptr, ptr, ptr, ptr, ptr, i32)
declare i32 @WinHttpSendRequest(ptr, ptr, i32, ptr, i32, i32, i64)
declare i32 @WinHttpReceiveResponse(ptr, ptr)
declare i32 @WinHttpReadData(ptr, ptr, i32, ptr)
declare i32 @WinHttpCloseHandle(ptr)

define i32 @http_post(ptr %url, ptr %headers, ptr %body, ptr %resp_buf, i32 %resp_size) {
  ; 1. Parse URL
  ; 2. WinHttpOpen
  ; 3. WinHttpConnect
  ; 4. WinHttpOpenRequest
  ; 5. WinHttpSendRequest
  ; 6. WinHttpReceiveResponse
  ; 7. WinHttpReadData
  ; 8. Cleanup
  ; 9. Return status code
}
```

## 测试方案

### 测试1：JSON构建
```bash
lli json_builder.ll
# 输出应该是有效的OpenAI/Claude API JSON
```

### 测试2：JSON解析
```bash
echo '{"choices":[{"message":{"content":"define i32 @main() { ret i32 0 }"}}]}' | lli json_parser.ll
# 应该提取出IR代码
```

### 测试3：端到端vibe
```bash
# 需要设置API密钥环境变量
export OPENAI_API_KEY="sk-..."
lli vibe_demo.ll
# 输入：print hello world
# 输出：生成的IR代码被编译并执行
```

## 文件清单

需要创建/修改的文件：
1. ✅ `src_ir/vibe_engine.ll` - 已存在，需完善TODO部分
2. 🆕 `src_ir/platform_windows.ll` - Windows平台层
3. 🆕 `src_ir/json_builder.ll` - JSON构建器
4. 🆕 `src_ir/json_parser.ll` - JSON解析器
5. 🆕 `examples/vibe_demo.ll` - 完整可运行demo
6. 🆕 `tests/test_json.ll` - JSON功能单元测试
7. 📝 `VIBE_GUIDE.md` - 使用指南

## 时间估算

- 平台层（HTTP + 内存）：2-3小时
- JSON构建器：1小时
- JSON解析器：1-2小时
- 完善vibe_engine.ll：1小时
- Demo和测试：1小时
- **总计：6-8小时**

## 风险和限制

1. **WinHTTP复杂性** - 可能需要大量样板代码
2. **JSON解析鲁棒性** - 简单实现可能无法处理所有edge case
3. **API密钥管理** - 需要通过环境变量或配置文件
4. **错误处理** - 网络失败、API错误等需要妥善处理
5. **TLS/HTTPS** - WinHTTP默认支持，但需要正确配置

## 替代方案

如果WinHTTP太复杂，可以：
- 使用libcurl（更简单的C API）
- 先用system("curl ...")作为临时方案
- 为不同平台提供不同实现

## 成功标准

✅ 用户输入意图 → AI生成IR代码 → 本地编译 → 成功执行
✅ 所有代码都是.ll文件
✅ 可以选择OpenAI或Claude
✅ 错误有明确提示
✅ 有完整使用文档
