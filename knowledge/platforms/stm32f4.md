# STM32F4 Platform Notes

## Memory Map

| Region | Start | End | Size | Notes |
|--------|-------|-----|------|-------|
| Flash | 0x08000000 | 0x080FFFFF | 1MB (F407) | Code storage |
| SRAM1 | 0x20000000 | 0x2001FFFF | 128KB | Main RAM |
| SRAM2 | 0x2001C000 | 0x2001FFFF | 16KB | Also accessible via bit-band |
| CCM | 0x10000000 | 0x1000FFFF | 64KB | Core-coupled, no DMA |
| Peripherals | 0x40000000 | 0x5FFFFFFF | — | APB1/APB2/AHB1/AHB2 |

## Key Registers for Exploration

| Address | Register | What it tells you |
|---------|----------|-------------------|
| 0xE000ED00 | CPUID | CPU type (Cortex-M4 = 0x410FC241) |
| 0xE000ED88 | CPACR | FPU access control |
| 0x1FFF7A10 | UID[0:2] | 96-bit unique device ID |
| 0x1FFF7A22 | Flash size | Flash size in KB (16-bit) |
| 0x40023800 | RCC_CR | Clock control (HSI/HSE/PLL status) |

## UART (USART2 as example)

- Base: 0x40004400
- SR (status): base + 0x00
  - Bit 7: TXE (transmit empty)
  - Bit 5: RXNE (receive not empty)
- DR (data): base + 0x04
- BRR (baud rate): base + 0x08
- CR1 (control): base + 0x0C
  - Bit 13: UE (UART enable)
  - Bit 3: TE (transmitter enable)
  - Bit 2: RE (receiver enable)

## Boot Sequence

1. CPU reads initial SP from 0x08000000
2. CPU reads reset vector from 0x08000004
3. Jumps to reset handler
4. Typical init: enable HSE → configure PLL → switch system clock → enable peripheral clocks → jump to main

## Clock Tree

Default after reset: HSI (16 MHz internal RC).
For full speed (168 MHz): HSE → PLL → SYSCLK.

RCC registers at 0x40023800:
- RCC_CR: enable HSE (bit 16), wait for HSERDY (bit 17)
- RCC_PLLCFGR: configure PLL multipliers
- RCC_CFGR: select system clock source

## GPIO

Base addresses: GPIOA=0x40020000, GPIOB=0x40020400, ...
Each GPIO port: MODER (+0x00), OTYPER (+0x04), OSPEEDR (+0x08), PUPDR (+0x0C), IDR (+0x10), ODR (+0x14), AFRL (+0x20), AFRH (+0x24)

To use UART2 on PA2/PA3: set GPIOA MODER to AF mode, AFRL to AF7.
