# Hand-written RV32I optimal solver. The public entry preserves all s registers.
# s6/s7: near-table/Bloom bases; s8/s9: permutation/orientation transitions;
# s10/s11: permutation/orientation lower bounds. Private routines inherit these
# read-only bases. Search recurses at most six edges, using 48 bytes per edge.
    .text
    .align 2
    .globl rubik_solve_asm
    .type rubik_solve_asm, @function
rubik_solve_asm:
    addi sp, sp, -160
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    sw s5, 24(sp)
    sw s6, 28(sp)
    sw s7, 32(sp)
    sw s8, 36(sp)
    sw s9, 40(sp)
    sw s10, 44(sp)
    sw s11, 48(sp)
    mv s0, a1
    mv s1, a2
    mv s4, a0
    li s2, 0
    li t0, 0
    li t1, 0
.Lr_parse_p:
    add t2, s4, t0
    lbu t3, 0(t2)
    addi t3, t3, -49
    sltiu t4, t3, 7
    beqz t4, .Lr_invalid
    li t4, 1
    sll t4, t4, t3
    and t5, t1, t4
    bnez t5, .Lr_invalid
    # Count unused values below this digit for its Lehmer digit.
    addi t5, t4, -1
    not t6, t1
    and t5, t5, t6
    li a3, 0
.Lr_popcount:
    beqz t5, .Lr_rank
    addi t6, t5, -1
    and t5, t5, t6
    addi a3, a3, 1
    j .Lr_popcount
.Lr_rank:
    or t1, t1, t4
    li t4, 7
    sub t4, t4, t0
    mv t5, s2
    li s2, 0
.Lr_rank_mul:
    add s2, s2, t5
    addi t4, t4, -1
    bnez t4, .Lr_rank_mul
    add s2, s2, a3
    addi t0, t0, 1
    li t2, 7
    bltu t0, t2, .Lr_parse_p
    li t0, 0
    li t1, 0
    li s3, 0
.Lr_parse_o:
    add t2, s4, t0
    lbu t3, 7(t2)
    addi t3, t3, -49
    sltiu t4, t3, 3
    beqz t4, .Lr_invalid
    add t1, t1, t3
    li t4, 6
    beq t0, t4, .Lr_o_last
    slli t4, s3, 1
    add s3, s3, t4
    add s3, s3, t3
.Lr_o_last:
    addi t0, t0, 1
    li t2, 7
    bltu t0, t2, .Lr_parse_o
    lbu t0, 14(s4)
    bnez t0, .Lr_invalid
    li t0, 3
.Lr_mod3:
    bltu t1, t0, .Lr_check_sum
    addi t1, t1, -3
    j .Lr_mod3
.Lr_check_sum:
    bnez t1, .Lr_invalid
    la s6, .Lr_near
    la s7, .Lr_bloom
    la s8, .Lr_perm
    la s9, .Lr_ori
    la s10, .Lr_hp
    la s11, .Lr_ho
    mv a0, s2
    mv a1, s3
    jal ra, .Lr_lookup
    beqz a0, .Lr_far_start
    mv a5, a0
    mv a0, s2
    mv a1, s3
    addi a4, sp, 64
    jal ra, .Lr_finish
    mv s5, a0
    j .Lr_format
.Lr_far_start:
    slli a0, s2, 10
    or a0, a0, s3
    jal ra, .Lr_is_diameter
    beqz a0, .Lr_lower_bound
    li s4, 11
    li t0, 11
    sw t0, 80(sp)
    j .Lr_bound_loop
.Lr_lower_bound:
    li t0, 10
    sw t0, 80(sp)
    add t0, s10, s2
    lbu s4, 0(t0)
    add t0, s11, s3
    lbu t1, 0(t0)
    bgeu s4, t1, .Lr_min_bound
    mv s4, t1
.Lr_min_bound:
    li t0, 6
    bgeu s4, t0, .Lr_bound_loop
    li s4, 6
.Lr_bound_loop:
    mv a0, s2
    mv a1, s3
    mv a2, s4
    li a3, 3
    addi a4, sp, 64
    jal ra, .Lr_search
    bgez a0, .Lr_found
    addi s4, s4, 1
    lw t0, 80(sp)
    bgeu t0, s4, .Lr_bound_loop
    j .Lr_invalid
.Lr_found:
    mv s5, a0
.Lr_format:
    # Compute required bytes before touching the caller's buffer.
    li t0, 0
    li t1, 1
    addi t2, sp, 64
    la t4, .Lr_suffix
.Lr_size_loop:
    bge t0, s5, .Lr_size_done
    add t3, t2, t0
    lbu t3, 0(t3)
    add t3, t4, t3
    lbu t3, 0(t3)
    snez t3, t3
    snez t5, t0
    add t1, t1, t3
    add t1, t1, t5
    addi t1, t1, 1
    addi t0, t0, 1
    j .Lr_size_loop
.Lr_size_done:
    bltu s1, t1, .Lr_small
    li t0, 0
    mv t1, s0
    addi t2, sp, 64
.Lr_write_loop:
    bge t0, s5, .Lr_write_done
    beqz t0, .Lr_write_face
    li t3, 32
    sb t3, 0(t1)
    addi t1, t1, 1
.Lr_write_face:
    add t3, t2, t0
    lbu t3, 0(t3)
    la t4, .Lr_faces_of
    add t4, t4, t3
    lbu t4, 0(t4)
    la t5, .Lr_faces
    add t4, t5, t4
    lbu t4, 0(t4)
    sb t4, 0(t1)
    addi t1, t1, 1
    la t4, .Lr_suffix
    add t4, t4, t3
    lbu t4, 0(t4)
    beqz t4, .Lr_write_next
    sb t4, 0(t1)
    addi t1, t1, 1
.Lr_write_next:
    addi t0, t0, 1
    j .Lr_write_loop
.Lr_write_done:
    sb zero, 0(t1)
    mv a0, s5
    j .Lr_exit
.Lr_small:
    beqz s1, .Lr_small_return
    sb zero, 0(s0)
.Lr_small_return:
    li a0, -2
    j .Lr_exit
.Lr_invalid:
    li a0, -1
.Lr_exit:
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    lw s4, 20(sp)
    lw s5, 24(sp)
    lw s6, 28(sp)
    lw s7, 32(sp)
    lw s8, 36(sp)
    lw s9, 40(sp)
    lw s10, 44(sp)
    lw s11, 48(sp)
    addi sp, sp, 160
    ret
    .size rubik_solve_asm, .-rubik_solve_asm

# a0=p, a1=o -> a0=packed near entry, or zero. Only a0 and t0..t6 change.
# A Bloom miss is conclusive; every hit is checked against the sorted table.
    .type .Lr_lookup, @function
.Lr_lookup:
    slli t0, a0, 10
    or t0, t0, a1
    srli t1, t0, 10
    srli t2, t0, 16
    xor t1, t1, t0
    xor t1, t1, t2
    srli t2, t1, 5
    andi t2, t2, 2047
    slli t2, t2, 2
    add t2, s7, t2
    lw t2, 0(t2)
    srl t2, t2, t1
    andi t2, t2, 1
    beqz t2, .Lr_lookup_miss
    li t1, 0
    li t2, 12224
.Lr_lookup_loop:
    bgeu t1, t2, .Lr_lookup_miss
    add t3, t1, t2
    srli t3, t3, 1
    slli t4, t3, 2
    add t4, s6, t4
    lw t5, 0(t4)
    srli t6, t5, 7
    beq t6, t0, .Lr_lookup_hit
    bltu t6, t0, .Lr_lookup_right
    mv t2, t3
    j .Lr_lookup_loop
.Lr_lookup_right:
    addi t1, t3, 1
    j .Lr_lookup_loop
.Lr_lookup_hit:
    mv a0, t5
    ret
.Lr_lookup_miss:
    li a0, 0
    ret
    .size .Lr_lookup, .-.Lr_lookup

# a0=packed state -> a0=whether the state is at the diameter. t0..t6 scratch.
    .type .Lr_is_diameter, @function
.Lr_is_diameter:
    la t0, .Lr_diameter
    li t1, 0
    li t2, 2644
.Lr_diameter_loop:
    bgeu t1, t2, .Lr_lookup_miss
    add t3, t1, t2
    srli t3, t3, 1
    slli t4, t3, 2
    add t4, t4, t0
    lw t5, 0(t4)
    beq t5, a0, .Lr_diameter_yes
    bltu t5, a0, .Lr_diameter_right
    mv t2, t3
    j .Lr_diameter_loop
.Lr_diameter_right:
    addi t1, t3, 1
    j .Lr_diameter_loop
.Lr_diameter_yes:
    li a0, 1
    ret
    .size .Lr_is_diameter, .-.Lr_is_diameter

# a0=p, a1=o, a4=path, a5=near entry -> a0=exact suffix length.
# Preserves all s registers, consumes only entries proven present by lookup.
    .type .Lr_finish, @function
.Lr_finish:
    srli t0, a5, 4
    andi t0, t0, 7
    beqz t0, .Lr_lookup_miss
    addi sp, sp, -32
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    mv s0, a0
    mv s1, a1
    mv s2, a4
    mv s3, t0
    mv s4, t0
.Lr_finish_loop:
    andi t0, a5, 15
    sb t0, 0(s2)
    addi s2, s2, 1
    la t1, .Lr_faces_of
    add t1, t1, t0
    lbu t3, 0(t1)
    slli t3, t3, 1
    la t1, .Lr_turns
    add t1, t1, t0
    lbu t4, 0(t1)
.Lr_finish_turn:
    slli t0, s0, 1
    slli t1, s0, 2
    add t0, t0, t1
    add t0, t0, t3
    add t0, s8, t0
    lhu s0, 0(t0)
    slli t0, s1, 1
    slli t1, s1, 2
    add t0, t0, t1
    add t0, t0, t3
    add t0, s9, t0
    lhu s1, 0(t0)
    addi t4, t4, -1
    bnez t4, .Lr_finish_turn
    addi s4, s4, -1
    beqz s4, .Lr_finish_done
    mv a0, s0
    mv a1, s1
    jal ra, .Lr_lookup
    mv a5, a0
    j .Lr_finish_loop
.Lr_finish_done:
    mv a0, s3
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    lw s4, 20(sp)
    addi sp, sp, 32
    ret
    .size .Lr_finish, .-.Lr_finish

# a0=p,a1=o,a2=remaining,a3=last face,a4=path -> a0=length or -1.
# The admissible coordinate bounds prune before a frame is allocated.
    .type .Lr_search, @function
.Lr_search:
    add t0, s10, a0
    lbu t0, 0(t0)
    bltu a2, t0, .Lr_search_fail
    add t0, s11, a1
    lbu t0, 0(t0)
    bltu a2, t0, .Lr_search_fail
    li t0, 5
    bltu t0, a2, .Lr_expand
    addi sp, sp, -32
    sw ra, 0(sp)
    sw a0, 4(sp)
    sw a1, 8(sp)
    sw a2, 12(sp)
    sw a4, 16(sp)
    jal ra, .Lr_lookup
    beqz a0, .Lr_leaf_fail
    srli t0, a0, 4
    andi t0, t0, 7
    lw t1, 12(sp)
    bltu t1, t0, .Lr_leaf_fail
    mv a5, a0
    lw a0, 4(sp)
    lw a1, 8(sp)
    lw a4, 16(sp)
    jal ra, .Lr_finish
    j .Lr_leaf_exit
.Lr_leaf_fail:
    li a0, -1
.Lr_leaf_exit:
    lw ra, 0(sp)
    addi sp, sp, 32
    ret
.Lr_expand:
    addi sp, sp, -48
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    sw s5, 24(sp)
    sw a3, 28(sp)
    sw a4, 32(sp)
    mv s0, a0
    mv s1, a1
    mv s2, a2
    li s3, 0
.Lr_face_loop:
    lw t0, 28(sp)
    beq t0, s3, .Lr_next_face
    mv s4, s0
    mv s5, s1
    sw zero, 36(sp)
.Lr_turn_loop:
    slli t3, s3, 1
    slli t0, s4, 1
    slli t1, s4, 2
    add t0, t0, t1
    add t0, t0, t3
    add t0, t0, s8
    lhu s4, 0(t0)
    slli t0, s5, 1
    slli t1, s5, 2
    add t0, t0, t1
    add t0, t0, t3
    add t0, t0, s9
    lhu s5, 0(t0)
    mv a0, s4
    mv a1, s5
    addi a2, s2, -1
    mv a3, s3
    lw a4, 32(sp)
    addi a4, a4, 1
    jal ra, .Lr_search
    bgez a0, .Lr_search_found
    lw t0, 36(sp)
    addi t0, t0, 1
    sw t0, 36(sp)
    li t1, 3
    bltu t0, t1, .Lr_turn_loop
.Lr_next_face:
    addi s3, s3, 1
    li t0, 3
    bltu s3, t0, .Lr_face_loop
    li a0, -1
    j .Lr_search_exit
.Lr_search_found:
    addi a0, a0, 1
    slli t0, s3, 1
    add t0, t0, s3
    lw t1, 36(sp)
    add t0, t0, t1
    lw t1, 32(sp)
    sb t0, 0(t1)
.Lr_search_exit:
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    lw s4, 20(sp)
    lw s5, 24(sp)
    addi sp, sp, 48
    ret
.Lr_search_fail:
    li a0, -1
    ret
    .size .Lr_search, .-.Lr_search

    .section .rodata
.Lr_faces_of:
    .byte 0,0,0,1,1,1,2,2,2
.Lr_turns:
    .byte 1,2,3,1,2,3,1,2,3
.Lr_suffix:
    .byte 0,50,39,0,50,39,0,50,39
.Lr_faces:
    .ascii "RBD"
    .include "src/rubik/tables.inc"
