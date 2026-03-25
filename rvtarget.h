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

// FPGA Debug MMIO access
#define FPGA_DEBUG_ADDR  0x10600000
#define FPGA_DEBUG_REG   *((volatile uint32_t *) FPGA_DEBUG_ADDR)
#define FPGA_CTRL_ADDR   0x10600010
#define FPGA_CTRL_REG    *((volatile uint32_t *) (FPGA_CTRL_ADDR))

// Exit status
#define EXIT_STATUS_ADDR  0x10601000
#define EXIT_STATUS_REG   *((volatile uint32_t *) EXIT_STATUS_ADDR)

// ACLINT memory map region 
#define MTIMER_BASE_ADDR        0x20000000
#define MTIMER_COUNTER          *((volatile uint64_t *) MTIMER_BASE_ADDR)

#define MTIMER_CMP_BASE_ADDR    0x20008000
#define MTIMER_CMP              *((volatile uint64_t *) MTIMER_CMP_BASE_ADDR)

#define ACLINT_MSIP_BASE_ADDR   0x20010000
#define ACLINT_MSIP_REGS        ((volatile uint32_t *) ACLINT_MSIP_BASE_ADDR)

// Serial emulator
#define SERIAL_BASE_ADDR        0x10600000
// Transmiter
#define SERIAL_TX_STATUS_ADDR   (SERIAL_BASE_ADDR)
#define SERIAL_TX_STATUS        *((volatile uint32_t *) SERIAL_TX_STATUS_ADDR)
#define SERIAL_TX_DATA_ADDR     (SERIAL_BASE_ADDR + 4)
#define SERIAL_TX_DATA          *((volatile uint32_t *) SERIAL_TX_DATA_ADDR)
// Receiver
#define SERIAL_RX_STATUS_ADDR   (SERIAL_BASE_ADDR + 4 * 2)
#define SERIAL_RX_STATUS        *((volatile uint32_t *) SERIAL_RX_STATUS_ADDR)
#define SERIAL_RX_DATA_ADDR     (SERIAL_BASE_ADDR + 4 * 3)
#define SERIAL_RX_DATA          *((volatile uint32_t *) SERIAL_RX_DATA_ADDR)

// Debug
#define DEBUG_REQ_ADDR    0x10602000
#define DEBUG_REQ_REG     *((volatile uint32_t *) DEBUG_REQ_ADDR)

// External profiler
#define PROFILER_BASE_ADDR            0x10700000
#define PROFILER_COUNTER_START_ADDR   (PROFILER_BASE_ADDR)
#define PROFILER_COUNTER_START        *((volatile uint32_t *) PROFILER_COUNTER_START_ADDR)
#define PROFILER_STOP_ADDR            (PROFILER_BASE_ADDR + 4)
#define PROFILER_COUNTER_STOP         *((volatile uint32_t *) PROFILER_STOP_ADDR)

// AXI master memory region
#define AXI_BASE_ADDR                  0x70000000
#define AXI_REGS                       ((volatile uint32_t *) AXI_BASE_ADDR)

#endif
