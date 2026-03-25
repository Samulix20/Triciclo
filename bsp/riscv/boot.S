.section .boot, "xa"
.globl __boot
.option norvc

# Same bootcode as spike

__boot:
    auipc   t0, 0x0
    addi    a1, t0, 32
    csrr    a0, mhartid
    lw      t0, 24(t0)
    jr      t0
    .word   0x00000000
    .word   0x80000000
