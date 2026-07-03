#ifndef RV_TARGET_H
#define RV_TARGET_H

#define BOOTROM_START_ADDR    0x00001000
#define BOOTROM_SIZE          1k

#define DRAM_START_ADDR       0x80000000
#define DRAM_SIZE             262144k // 256 MiB
#define STACK_SIZE            51200k  // 50 MiB
#define HEAP_SIZE             51200k  // 50 MiB

#define FPGA_RAM_SIZE    128k
#define FPGA_STACK_SIZE  10k
#define FPGA_HEAP_SIZE   10k

// Exit status
#define EXIT_STATUS_ADDR  0x10010000
#define EXIT_STATUS_REG   *((volatile uint32_t *) EXIT_STATUS_ADDR)


#define SERIAL_BASE_ADDR        0x20000000

#define SERIAL_TXDATA_ADDR      (SERIAL_BASE_ADDR + 0x00)
#define SERIAL_TXDATA           *((volatile uint32_t *) SERIAL_TXDATA_ADDR)
#define SERIAL_RXDATA_ADDR      (SERIAL_BASE_ADDR + 0x04)
#define SERIAL_RXDATA           *((volatile uint32_t *) SERIAL_RXDATA_ADDR)
#define SERIAL_TXCTRL_ADDR      (SERIAL_BASE_ADDR + 0x08)
#define SERIAL_TXCTRL           *((volatile uint32_t *) SERIAL_TXCTRL_ADDR)
#define SERIAL_RXCTRL_ADDR      (SERIAL_BASE_ADDR + 0x0C)
#define SERIAL_RXCTRL           *((volatile uint32_t *) SERIAL_RXCTRL_ADDR)
#define SERIAL_IE_ADDR          (SERIAL_BASE_ADDR + 0x10)
#define SERIAL_IE                *((volatile uint32_t *) SERIAL_IE_ADDR)
#define SERIAL_IP_ADDR          (SERIAL_BASE_ADDR + 0x14)
#define SERIAL_IP                *((volatile uint32_t *) SERIAL_IP_ADDR)
#define SERIAL_DIV_ADDR         (SERIAL_BASE_ADDR + 0x18)
#define SERIAL_DIV                *((volatile uint32_t *) SERIAL_DIV_ADDR)


#define SERIAL_RXDATA_EMPTY_BIT  (1u << 31)

// Debug
#define DEBUG_REQ_ADDR    0x10030000
#define DEBUG_REQ_REG     *((volatile uint32_t *) DEBUG_REQ_ADDR)

// External profiler
#define PROFILER_BASE_ADDR            0x10040000
#define PROFILER_COUNTER_START_ADDR   (PROFILER_BASE_ADDR)
#define PROFILER_COUNTER_START        *((volatile uint32_t *) PROFILER_COUNTER_START_ADDR)
#define PROFILER_STOP_ADDR            (PROFILER_BASE_ADDR + 4)
#define PROFILER_COUNTER_STOP         *((volatile uint32_t *) PROFILER_STOP_ADDR)


// ACLINT memory map region 
#define MTIMER_BASE_ADDR        0x02000000
#define MTIMER_COUNTER          *((volatile uint64_t *) MTIMER_BASE_ADDR)

#define MTIMER_CMP_BASE_ADDR    0x02004000
#define MTIMER_CMP              *((volatile uint64_t *) MTIMER_CMP_BASE_ADDR)

#define ACLINT_MSIP_BASE_ADDR   0x02008000
#define ACLINT_MSIP_REGS        ((volatile uint32_t *) ACLINT_MSIP_BASE_ADDR)

// AXI master memory region
#define AXI_BASE_ADDR                  0x30000000
#define AXI_REGS                       ((volatile uint32_t *) AXI_BASE_ADDR)

#endif