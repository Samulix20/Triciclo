#include <riscv/csr.h>
#include <riscv/irq.h>

#include <stdio.h>
#include <stdlib.h>

const u8 sbi_params_start = 10 - 3; 

void _trap_handler(u32* saved_ctx) {
    u32 mcause = read_mcause();

    switch (mcause) {
        case MCAUSE_MACHINE_ECALL:
            printf("Ecall from M. SBI parameter regs:\n");
            // Print all sbi param regs
            for (u32 i = 0; i < 8; i++) {
                u32 p = sbi_params_start + i;
                u32 v = saved_ctx[p];
                printf("\ta%lu (x%lu) = %lx\n", i, p, v);
            }
            // Return to next instruction not the ecall
            write_mepc(read_mepc() + 4);
        break;

        case MCAUSE_TIMER_IRQ:
            _mtimer_irq();
        break;

        case MCAUSE_MACHINE_EXT_IRQ:
            _mei_irq();
        break;

        case MCAUSE_SOFT_IRQ:
            _msi_irq();
        break;
        
        default:
            printf("Unexpected mcause found: 0x%08lx\n", mcause);
            printf("MEPC: 0x%08lx\n", read_mepc());
            printf("MSCRATCH: 0x%08lx\n", read_mscratch());
            exit(-1);
        break;
    }
}
