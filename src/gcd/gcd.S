# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# Register use: a0/a1 are the reduced operands, a2 counts common factors of
# two, and t0 is a bit-test temporary. Leaf function; no stack or saved
# registers. The two reduction paths avoid swapping the operands.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    beqz    a0, .Lreturn_b
    beqz    a1, .Lreturn
    li      a2, 0
.Lcommon:
    or      t0, a0, a1
    andi    t0, t0, 1
    bnez    t0, .Lodd_a
    srli    a0, a0, 1
    srli    a1, a1, 1
    addi    a2, a2, 1
    j       .Lcommon
.Lshift_a:
    srli    a0, a0, 1
.Lodd_a:
    andi    t0, a0, 1
    beqz    t0, .Lshift_a
    j       .Lodd_b
.Lshift_b:
    srli    a1, a1, 1
.Lodd_b:
    andi    t0, a1, 1
    beqz    t0, .Lshift_b
.Lcompare:
    beq     a0, a1, .Ldone
    bltu    a0, a1, .Lreduce_b
    sub     a0, a0, a1
    # The difference of unequal odd operands is positive and even.
.Lreduce_a_shift:
    srli    a0, a0, 1
    andi    t0, a0, 1
    beqz    t0, .Lreduce_a_shift
    j       .Lcompare
.Lreduce_b:
    sub     a1, a1, a0
.Lreduce_b_shift:
    srli    a1, a1, 1
    andi    t0, a1, 1
    beqz    t0, .Lreduce_b_shift
    j       .Lcompare
.Ldone:
    sll     a0, a0, a2
.Lreturn:
    ret
.Lreturn_b:
    mv      a0, a1
    ret
    .size   gcd_u32_asm, .-gcd_u32_asm
