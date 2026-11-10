# Logic arithmetic and Q11.20 on RV32I

Draft for Homework 2. The measured implementation is pinned at commit
`844625364e75c44cb9b31b12b1b390b3c273b775`:

- [C source](https://github.com/Edison1019/arch2026-progs/blob/844625364e75c44cb9b31b12b1b390b3c273b775/src/fixed/fixed.c)
- [Hand-written assembly](https://github.com/Edison1019/arch2026-progs/blob/844625364e75c44cb9b31b12b1b390b3c273b775/src/fixed/fixed.S)

## Contracts and derivation

### Carry propagation

For unsigned words, `a + b = (a ^ b) + 2 * (a & b)` modulo 2^32.
The XOR gives the sum without carries; the shifted AND supplies the carries.
`op1` repeats this transformation until the carry word is zero, recording
every pass. It cannot be replaced with a single add because the pass count
is observable. Each pass moves the lowest possible remaining carry to a
higher bit, so at most 32 passes are needed. With a zero second operand,
there are no passes. The assembly uses t1 for the new carry so it need not
copy the old second operand, unlike the O1 compiler listing.

### Subtraction and average

`op2` is unsigned subtraction modulo 2^32, implemented by `sub` and `ret`.
For `op3`, the same identity gives

```
floor((a + b) / 2) = (a & b) + ((a ^ b) >> 1).
```

This identity uses the exact mathematical sum without forming a potentially
overflowing 32-bit sum. Its result lies between the inputs, hence fits in a
word. The C implementation directly expresses the identity:

```c
return (a & b) + ((a ^ b) >> 1);
```

The assembly uses AND, XOR, logical shift, add and return. The compiler
already emits these minimal straightforward sequences for op2 and op3;
matching them is expected, and no speed improvement is claimed for them.

### Signed fixed-point multiply

A stored signed integer A represents A / 2^20. The range is -2048 through
2048 - 2^-20 and the spacing is 2^-20. Multiplying stored integers A and B
produces a value with 40 fractional bits. The required stored result is

```
R = floor((A * B + 2^19) / 2^20) modulo 2^32.
```

The bias rounds ties toward positive infinity, including negative ties:
`q_mul(3, 524288) = 2`, but `q_mul(-3, 524288) = -1`.
Overflow wraps; it does not saturate. Before wrapping, rounding error is at
most 2^-21 in represented real units. After wrapping, this small absolute
error bound does not apply to the difference from the unbounded real product.

Let U and V be the unsigned bit patterns of A and B, with sign indicators
sA and sB. Then

```
A = U - sA * 2^32
B = V - sB * 2^32
A * B = U * V - (sA * V + sB * U) * 2^32 modulo 2^64.
```

Both versions form U*V with shift-and-add in two unsigned words. Subtracting
the correction from the high word gives the signed product bit pattern.
Starting the accumulator at 2^19 incorporates rounding without a separate
carry-propagating addition at the end. Low-word addition carries exactly when
the wrapped sum is smaller than either addend. The assembly uses this fact:

```asm
add     t0, t0, a0
sltu    t3, t0, a0
add     t1, t1, a2
add     t1, t1, t3
```

Here t1:t0 is the accumulator and a2:a0 is the shifted multiplicand. The final
word is `(low >> 20) | (high << 12)`. Although the contract describes a
64-bit arithmetic shift, its sign extension affects only higher discarded
bits, so this word splice gives the required wrapped result.

The C version uses only unsigned shifts/additions and avoids a signed 64-bit
multiply that would request the unavailable `__muldi3`. It also converts the
result to signed without an out-of-range unsigned-to-signed conversion.
INT32_MIN does not need a special absolute-value case. The assembly is a
leaf routine, uses only caller-saved registers, and calls no helper.

## Optimization experiment

The first working one-bit assembly loop had 180 bytes of total implementation
text and needed 212.0000 net cycles per q_mul call in the O1 ELF. Its worst
measured q_mul call needed 403 instructions. Expanding the step twice lets
one multiplier shift and one loop branch serve two bits, giving at most
16 iterations. The final version has 220 bytes of text, needs 195.7500 net
cycles per call in that ELF, and a worst measured count of 371. This is a
7.67% reduction in net benchmark instructions at a cost of 40 code bytes.
The zero-input shortcut is valid for all inputs and precedes the loop.

## Validation

All four target builds passed 38 tests each. The host passed 15 tests under
AddressSanitizer and UBSan. Tests cover directed values, grids, random pairs,
carry pass counts, arithmetic laws, full-width averages, fixed-point identity
and sign cases, ties and wrap-around. The multiply reference uses independent
16-bit partial products. Assembly is also cross-checked against C.

The measured maximum instruction counts across the four builds were:

| Function | C maximum | Assembly maximum | Assembly budget |
| --- | ---: | ---: | ---: |
| op1 | 201 | 169 | 600 |
| op2 | 6 | 6 | 40 |
| op3 | 9 | 9 | 40 |
| q_mul | 462 | 371 | 1200 |

These maxima are over the provided directed and random tests, not exhaustive
over all operand pairs. Independently, op1 takes at most 32 iterations and
q_mul at most 16 two-bit iterations, bounding the general paths. Each
expanded multiply step has at most ten instructions, plus two per loop and
constant entry/exit work, so it stays well below 1,200 instructions.

The selected-program driver passed all checks. Its 55/55 is a result for
fixed and the shared checks, not the complete assignment score. Formatting,
Cppcheck and whitespace checks also passed. The other programs remain at
their current development stages.

## Measurements

Measured 2026-11-10 with xPack GCC 15.2.0, binutils 2.45 and rv32emu revision
`9dbff65c4d6a40d64d3bbb38f4c5a20d6e885e24`. C flags include
`-march=rv32i_zicsr -mabi=ilp32 -ffreestanding -fno-pic
-fno-stack-protector`, plus each optimization level below. Assembly is built
directly by GNU as. The emulator is the system interpreter with ELF loading
and no M/A/F/C extensions.

Each value below is net cycles per call: `(cycles - overhead) / 16`. Inputs
and timed regions are identical between implementations; setup and output
are excluded. The harness measures and subtracts its loop overhead. The
assembly from the O2 ELF is listed separately; comparisons use the assembly
measurement in the same ELF as the selected C build.

| Function | C O1 | C O2 | C O3 | C Os | Assembly O2 |
| --- | ---: | ---: | ---: | ---: | ---: |
| op1 | 24.7500 | 22.0625 | 24.1875 | 24.6875 | 22.1250 |
| op2 | 4.0000 | 4.0000 | 5.9375 | 4.0000 | 4.0000 |
| op3 | 7.0000 | 7.0000 | 8.9375 | 7.0000 | 7.0000 |
| q_mul | 213.9375 | 253.8125 | 255.7500 | 232.6875 | 195.7500 |

q_mul is 1.093x faster than the fastest C build (O1) in the same ELF, and
1.297x faster than the O2 C baseline. O2/O3 emit a different branch layout
and larger code than O1; greater optimization does not imply lower executed
instruction counts. op1 is effectively tied with its best C build: a
0.0625-cycle difference in the net average is measurement overhead, not an
algorithmic win. op2 and op3 match the compiler.

rv32emu counts guest instructions rather than modeling physical CPU timing.
No pipeline, cache, or multi-cycle latency conclusion follows from these
figures. The identical assembly object can have slightly different reported
costs because caller and overhead-measurement code changes across builds.

| Implementation | .text | .rodata | .data | .bss |
| --- | ---: | ---: | ---: | ---: |
| C O1 | 224 | 0 | 0 | 0 |
| C O2 | 264 | 0 | 0 | 0 |
| C O3 | 264 | 0 | 0 | 0 |
| C Os | 168 | 0 | 0 | 0 |
| Assembly | 220 | 0 | 0 | 0 |

Sizes exclude the test harness, metadata and debug sections. The assembly
trades a larger footprint than Os for faster multiplication.

## Applications and limits

Fixed-point arithmetic supports embedded graphics, control loops and signal
processing without an FPU. Its scale and rounding must be chosen with the
required dynamic range; wrap-around may be unsuitable where saturation is
needed. The carry model explains how logic implements addition, while the
average identity avoids an unnecessary wider intermediate. These routines
have data-dependent execution and are not constant-time cryptographic code.

## Reproduce

```bash
cd /home/edison/arch2026-progs
source /home/edison/arch2026-lab2/setenv
make build/host/fixed
build/host/fixed
make dump neg
scripts/driver.py --prog fixed
```

Raw logs are local generated files under `results/fixed-*.log`. The tables
above preserve the report data without committing generated logs.
