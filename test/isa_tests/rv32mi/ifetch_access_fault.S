#*****************************************************************************
# ifetch_access_fault.S
#-----------------------------------------------------------------------------
#
# Test that a straight-line (non-branch) instruction fetch which walks off
# the end of the mapped instruction-fetch PMA window raises
# CAUSE_INSTRUCTION_ACCESS_FAULT.

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_CODE_BEGIN

li gp, 1

la x1, mtvec_handler
csrrw x0, mtvec, x1

# absolute jump.
la x1, edge_runway
jr x1

  .align 2
  .global mtvec_handler
mtvec_handler:
  li a1, CAUSE_FETCH_ACCESS
  csrr a0, mcause
  bne a0, a1, fail

  # mepc must be the address that failed to fetch: one word past edge_runway.
  la a1, edge_runway
  addi a1, a1, 4
  csrr a0, mepc
  bne a0, a1, fail

  RVTEST_PASS

fail:
  RVTEST_FAIL

  # Zero-fill from here up to the last valid word
  .fill 0x83FFFFFC - 0x80000000 - (. - _start), 1, 0
  
  .global edge_runway
edge_runway:
  nop
