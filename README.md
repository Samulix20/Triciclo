# Triciclo (Tricycle)

Tiny 3 stage RISC-V processor with enough support to boot uClinux in M-mode.

# Requirements

- Python3
- Make
- GCC
- RISC-V GNU toolchain
- Verilator

## RISC-V GNU toolchain flags

Example RISC-V GNU multilib configuration

`
./configure --enable-multilib --with-multilib-generator="rv32ima_zicsr_zifencei;rv32i_c_zmmul_zicsr-ilp32--"
`

# References

- Sifive Serial, CLINT and PLIC https://cdn.sparkfun.com/assets/b/f/a/1/2/FE310-G000.pdf
