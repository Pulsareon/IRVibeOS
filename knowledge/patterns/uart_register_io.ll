; Pattern: UART register I/O (ARM Cortex-M style)
; 模式：UART 寄存器 I/O（ARM Cortex-M 风格）
;
; Most ARM MCUs have memory-mapped UART registers.
; 大多数 ARM MCU 使用内存映射的 UART 寄存器。
;
; Typical structure / 典型结构:
;   BASE + 0x00 = Data Register (DR) — read to receive, write to send
;                  数据寄存器 — 读取接收，写入发送
;   BASE + 0x04 = Status Register (SR) — check TX empty / RX ready flags
;                  状态寄存器 — 检查发送空/接收就绪标志
;
; This pattern shows the general approach. Actual addresses vary by chip.
; 此模式展示通用方法。实际地址因芯片而异。

; Example: hypothetical UART at base 0x40004400
; 示例：假设 UART 基地址 0x40004400
; SR bit 7 = TX empty / 发送空, SR bit 5 = RX not empty / 接收非空

define void @uart_send_byte(i8 %byte) {
entry:
  %sr_addr = inttoptr i64 1073759236 to ptr   ; 0x40004404
  br label %wait_tx

wait_tx:
  %sr = load volatile i32, ptr %sr_addr
  %tx_ready = and i32 %sr, 128               ; bit 7
  %ready = icmp ne i32 %tx_ready, 0
  br i1 %ready, label %send, label %wait_tx

send:
  %dr_addr = inttoptr i64 1073759232 to ptr   ; 0x40004400
  %val = zext i8 %byte to i32
  store volatile i32 %val, ptr %dr_addr
  ret void
}

define i8 @uart_recv_byte() {
entry:
  %sr_addr = inttoptr i64 1073759236 to ptr   ; 0x40004404
  br label %wait_rx

wait_rx:
  %sr = load volatile i32, ptr %sr_addr
  %rx_ready = and i32 %sr, 32                ; bit 5
  %ready = icmp ne i32 %rx_ready, 0
  br i1 %ready, label %recv, label %wait_rx

recv:
  %dr_addr = inttoptr i64 1073759232 to ptr   ; 0x40004400
  %val = load volatile i32, ptr %dr_addr
  %byte = trunc i32 %val to i8
  ret i8 %byte
}
