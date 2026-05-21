# See LICENSE for license details.

#*****************************************************************************
# lrsr.S
#-----------------------------------------------------------------------------
#
# Test LR/SC instructions.
#

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_CODE_BEGIN

# make sure that sc without a reservation fails.
TEST_CASE( 2, a4, 1, \
  la a0, foo; \
  li a5, 0xdeadbeef; \
  sc.w a4, a5, (a0); \
)

# make sure the failing sc did not commit into memory
TEST_CASE( 3, a4, 0, \
  lw a4, foo; \
)

# make sure that sc-after-successful-sc fails.
TEST_CASE( 6, a1, 2, \
  la a0, foo; \
1:lr.w a1, (a0); \
  sc.w a1, x0, (a0); \
  bnez a1, 1b; \
  sc.w a1, x0, (a0); \
  /* make sure that sc-after-failed-sc fails, too */ \
  sc.w a2, x0, (a0); \
  add a1, a1, a2
)

TEST_PASSFAIL

RVTEST_DATA_BEGIN

foo: .word 0
