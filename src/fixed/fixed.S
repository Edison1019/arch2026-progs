# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# All functions are RV32I leaf routines; no stack or saved registers.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    # a0/a1: partial sum/carry; t0: pass count; t1: next carry.
    li      t0, 0
    beqz    a1, .Lop1_done
.Lop1_loop:
    and     t1, a0, a1
    xor     a0, a0, a1
    slli    a1, t1, 1
    addi    t0, t0, 1
    bnez    a1, .Lop1_loop
.Lop1_done:
    sw      t0, 0(a2)
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub     a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    # t0: common bits; a0: differing bits, then their half plus common bits.
    and     t0, a0, a1
    xor     a0, a0, a1
    srli    a0, a0, 1
    add     a0, a0, t0
    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
    # Consume one multiplier bit, then double the multiplicand. Expanding
    # twice amortizes multiplier shifts and loop branches over two bits.
    .macro  q_step mask
    andi    t2, a1, \mask
    beqz    t2, 1f
    add     t0, t0, a0
    sltu    t3, t0, a0
    add     t1, t1, a2
    add     t1, t1, t3
1:
    srli    t2, a0, 31
    slli    a2, a2, 1
    or      a2, a2, t2
    slli    a0, a0, 1
    .endm
q_mul_asm:
    # a2:a0: shifted unsigned multiplicand; a1: unsigned multiplier.
    # t1:t0: product plus rounding bias; a3: signed high-word correction.
    # t2/t3: bit tests, old low word and carry. All additions wrap.
    beqz    a0, .Lq_zero
    beqz    a1, .Lq_zero
    srai    t2, a0, 31
    and     a3, t2, a1
    srai    t2, a1, 31
    and     t2, t2, a0
    add     a3, a3, t2
    li      a2, 0
    li      t0, 0x80000
    li      t1, 0
.Lq_loop:
    q_step  1
    q_step  2
    srli    a1, a1, 2
    bnez    a1, .Lq_loop
.Lq_done:
    sub     t1, t1, a3
    srli    a0, t0, 20
    slli    t1, t1, 12
    or      a0, a0, t1
    ret
.Lq_zero:
    li      a0, 0
    ret
    .size   q_mul_asm, .-q_mul_asm
