#include <riscv/types.h>

int main() {
    // Test that all sbi params registers can be read in handler
    asm volatile (
        "li a0, 1\n"
        "li a1, 2\n"
        "li a2, 3\n"
        "li a3, 4\n"
        "li a4, 5\n"
        "li a5, 6\n"
        "li a6, 7\n"
        "li a7, 8\n"
        "ecall\n"
    );
}
