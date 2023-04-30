# See LICENSE for license details.

#*****************************************************************************
# csr.S
#-----------------------------------------------------------------------------
#
# Test U-mode CSRs for N-extension
#

#include "riscv_test.h"
#include "test_macros.h"

#undef RVTEST_ENABLE_SUPERVISOR
#define RVTEST_ENABLE_SUPERVISOR                                        \
  li a0, MSTATUS_MPP & (MSTATUS_MPP >> 1);                              \
  csrs mstatus, a0;                                                     \
  li a0, SIP_SSIP | SIP_STIP | MIP_USIP;                                \
  csrs mideleg, a0;                                                     \

#define UINTC_BASE 0x3000000
#define UINTC_SEND(i) (UINTC_BASE + i * 0x20)
#define UITNC_LOW(i) (UINTC_BASE + i * 0x20 + 0x8)
#define UINTC_HIGH(i) (UINTC_BASE + i * 0x20 + 0x10)
#define UINTC_ACTIVE(i) (UINTC_BASE + i * 0x20 + 0x18)

RVTEST_RV64S
RVTEST_CODE_BEGIN

  # suirs: v=1, idx=0
  li t0, (1 << 63)
  csrw 0x1b1, t0
  TEST_CASE(0, t1, 0, csrr t1, 0x1b1; xor t1, t1, t0)
  # mode=1, hartid=a0, pendings=0
  slli t0, a0, 16
  ori t0, t0, 2
  li t1, UITNC_LOW(0)
  sd t0, 0(t1)
  li t1, UINTC_HIGH(0)
  sd zero, 0(t1) 

  # suist: v=1, uvec=3, uirs_idx=0
  la t0, uiste
  li t1, ((3 << 16) | 1)
  sd t1, 0(t0)
  srli t0, t0, 12
  li t1, ((1 << 63) | (1 << 44))
  or t0, t0, t1
  csrw 0x1b0, t0
  TEST_CASE(1, t1, 0, csrr t1, 0x1b0; xor t1, t1, t0)

  # jump to user land
  li t0, SSTATUS_SPP
  csrc sstatus, t0
  la t0, 1f
  csrw sepc, t0
  csrsi sideleg, MIP_USIP
  sret
  1:

finish:
  # setup user interrupt handler
  la t0, utvec_handler
  csrw utvec, t0

  # enable user interrupt
  csrsi ustatus, USTATUS_UIE
  csrci uip, MIP_USIP
  csrsi uie, MIP_USIP

  # activate
  .insn r 0b1111011, 0b010, 0b0000011, x0, x0, x0
  # deactivate
  .insn r 0b1111011, 0b010, 0b0000100, x0, x0, x0
  # activate
  .insn r 0b1111011, 0b010, 0b0000011, x0, x0, x0

  # send interrupt
  li t0, 0
  .insn r 0b1111011, 0b010, 0b0000000, x0, t0, x0

wait:
  li t0, 0xdead
  lw t1, result
  bne t0, t1, wait

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

  # read and clear pending bits
  TEST_CASE(2, t0, 8, .insn r 0b1111011, 0b010, 0b0000001, t0, x0, x0)
  TEST_CASE(3, t0, MIP_USIP, csrr t0, uip)
  csrci uip, MIP_USIP
  uret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  # 4KB aligned sender table
uiste:
  .dword 0

result:
  .dword 0
RVTEST_DATA_END