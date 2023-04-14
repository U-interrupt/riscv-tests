# See LICENSE for license details.

#*****************************************************************************
# csr.S
#-----------------------------------------------------------------------------
#
# Test U-mode CSRs for N-extension
#

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64S
RVTEST_CODE_BEGIN

  TEST_CASE(0, a0, 3, csrwi uscratch, 3; csrr a0, uscratch);
  TEST_CASE(1, a0, 3, csrwi utvec, 3; csrr a0, utvec);
  TEST_CASE(2, a0, 3, csrwi utval, 3; csrr a0, utval);
  TEST_CASE(3, a0, 3, csrwi uepc, 3; csrr a0, uepc);
  li a1, MIP_USIP;
  TEST_CASE(4, a0, 1, csrsi uip, IRQ_U_SOFT; csrr a0, uip; and a0, a0, a1);
  TEST_CASE(5, a0, 1, csrsi uie, IRQ_U_SOFT; csrr a0, uie; and a0, a0, a1);
  TEST_CASE(6, a0, 1, csrsi sideleg, IRQ_U_SOFT; csrr a0, sideleg; and a0, a0, a1);

  # jump to user land
  li t0, SSTATUS_SPP
  csrc sstatus, t0
  la t0, 1f
  csrw sepc, t0
  # setup user interrupt handler
  csrw uepc, t0
  la t0, utvec_handler
  csrw utvec, t0
  sret
  1:

finish:
  TEST_CASE(7, a0, 0xdead, lw a0, result);
  RVTEST_PASS

  # We should only fall through to this if scall failed.
  TEST_PASSFAIL


  .align 2
  .global stvec_handler
stvec_handler:
  # Trapping on tests 13-15 is good news.
  li t0, 13
  bltu TESTNUM, t0, 1f
  li t0, 15
  bleu TESTNUM, t0, privileged
1:

  # catch RVTEST_PASS and kick it up to M-mode
  csrr t0, scause
  li t1, CAUSE_USER_ECALL
  bne t0, t1, fail
  RVTEST_PASS

privileged:
  # Make sure scause indicates a lack of privilege.
  csrr t0, scause
  li t1, CAUSE_ILLEGAL_INSTRUCTION
  bne t0, t1, fail
  # Return to user mode, but skip the trapping instruction.
  csrr t0, sepc
  addi t0, t0, 4
  csrw sepc, t0
  sret

  .align 2
  .global utvec_handler
utvec_handler:
  li t0, 0xdead
  la t1, result
  sw t0, 0x0(t1)
  uret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  .align 3
result:
  .dword 0
RVTEST_DATA_END