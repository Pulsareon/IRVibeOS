; Pattern: UART register I/O (ARM Cortex-M style)
;
; Most ARM MCUs have memory-mapped UART registers.
; Typical structure:
;   BASE + 0x00 = Data Register (DR) — read to receive, write to send
;   BASE + 0x04 = Status Register (SR) — check TX empty / RX ready flags
;
; This pattern shows the general approach. Actual addresses vary by chip.

; Example for a hypothetical UART at base 0x40004400:
; SR bit 7 = TX empty, SR bit 5 = RX not empty

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
