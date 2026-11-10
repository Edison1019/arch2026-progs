# Binary GCD on RV32I

This is a draft for the GCD section of the Homework 2 report. The measured
implementation is pinned at commit
`11da8813f8eb8bf822dcb55d02582de19c4df67c`:

- [C source](https://github.com/Edison1019/arch2026-progs/blob/11da8813f8eb8bf822dcb55d02582de19c4df67c/src/gcd/gcd.c)
- [Hand-written assembly](https://github.com/Edison1019/arch2026-progs/blob/11da8813f8eb8bf822dcb55d02582de19c4df67c/src/gcd/gcd.S)

## Contract and algorithm

The inputs and result are unsigned 32-bit integers. The zero identities are
`gcd(a, 0) = a` and `gcd(0, b) = b`, including `gcd(0, 0) = 0`.

Stein's algorithm follows three identities:

1. `gcd(2a, 2b) = 2 gcd(a, b)`.
2. If `b` is odd, `gcd(2a, b) = gcd(a, b)`.
3. `gcd(a, b) = gcd(a, b - a)` when `b > a`.

The C implementation removes common powers of two and records their count.
It makes the first operand odd, then repeatedly makes the second operand odd,
orders the pair, and subtracts the smaller operand. The difference of odd
operands is even, so the next iteration removes at least one factor of two.
The result restores the common factor with a left shift.

Every reduction preserves the GCD and decreases a positive operand, giving
termination. Zeros are handled before normalization, and the C loop never
normalizes a zero operand. At most 31 common shifts are possible for nonzero
32-bit inputs. All C arithmetic uses unsigned values; subtraction is ordered
and the final result is representable.

With fixed-width words, the algorithm needs O(w) reduction rounds and O(1)
storage, where w is the bit width. Across the normalization steps, each right
shift decreases the sum of the operands' bit lengths, initially at most 64.
Subtractions do not increase that sum. This also bounds the total shift-loop
work by O(w), rather than permitting an unbounded subtraction-only loop.

## Hand-written assembly

The assembly keeps the operands in a0/a1, the common shift count in a2, and
bit-test scratch space in t0. It is a leaf function with no stack frame,
tables, runtime helper calls, or callee-saved register use.

Unlike the C implementation's swap-based loop, it has separate paths for
reducing a0 and a1. Both operands are odd at the comparison. Equality ends
the search immediately; otherwise unsigned comparison selects the larger
operand. Subtraction produces a positive even value, so its first right
shift can execute without a preceding parity test. These paths avoid moves
for swapping operands and preserve unsigned behavior above INT32_MAX.

RV32I lacks a count-trailing-zeros instruction. This implementation uses
one-bit shifts with parity tests. A binary-search normalization is a possible
future experiment, but it has not been implemented or measured here.

## Validation

The host build passed all 13 tests under AddressSanitizer and UBSan. Each
RV32I build at O1, O2, O3 and Os passed all 34 tests, including shared runtime
tests. GCD checks include all 65,536 input pairs below 256, zero identities,
all pairs of powers of two, shared even factors, random operands, Fibonacci
identities, instruction budgets, and 4,096 assembly/C comparisons.

The reference is an independent Euclidean algorithm using a software divider
in the test harness. GCD is exact integer arithmetic: no approximation error
is permitted. Cppcheck, clang-format 20.1.8 and `git diff --check` also passed.
The official `scripts/driver.py --prog gcd` check passed, including ISA,
external-symbol and performance checks. Its 55/55 result covers this selected
program and shared checks; it is not the complete assignment score.

## Measurements

Measured on 2026-11-10 with xPack GCC 15.2.0, binutils 2.45, and rv32emu
revision `9dbff65c4d6a40d64d3bbb38f4c5a20d6e885e24`. Implementation flags include
`-march=rv32i_zicsr -mabi=ilp32 -ffreestanding -fno-pic
-fno-stack-protector` and the indicated optimization level. The assembly is
assembled directly and shared across builds. The emulator uses system
interpreter mode, ELF loading, and no M/A/F/C extensions.

The harness uses the same 16 inputs for each implementation. Net cycles per
call are `(cycles - overhead) / 16`, using each line's measured loop overhead.
Initialization and printing are outside this timed region. Local raw
measurements are in `results/gcd-O1.log`, `gcd-O2.log`, `gcd-O3.log`, and
`gcd-Os.log`; these generated logs are not committed. The tables below retain
the numbers needed for the report.

| Build | C net cycles/call | Assembly net cycles/call | C worst measured instructions | Assembly worst measured instructions |
| --- | ---: | ---: | ---: | ---: |
| O1 | 101.6250 | 89.3125 | 367 | 329 |
| O2 | 116.6250 | 89.3125 | 457 | 329 |
| O3 | 118.8125 | 91.3125 | 457 | 329 |
| Os | 119.6875 | 89.3125 | 428 | 328 |

O1 is the best C build on these benchmark inputs. Compared within its ELF,
the hand-written version has a 1.138x speedup, reducing the net count by
about 12.1%. Compared with O2, the speedup is 1.306x. Higher optimization
levels do not guarantee fewer executed instructions for this branch-heavy
loop: the O2 listing has operand moves and a different loop/branch layout.
This comparison is between implementations of the same algorithm; no earlier
working assembly version was measured, so no assembly-to-assembly gain is
claimed.

The worst measured assembly call is 329 instructions, versus the 1,500
budget. This is a sampled maximum, not an exhaustive maximum over all 2^64
input pairs. The finite reduction/shift bounds above support bounded work
outside the samples. The C budget is 4,000 instructions per call.

rv32emu has no physical timing model: its cycle and instret CSRs count guest
instructions. These numbers do not establish pipeline or cache behavior.
The small differences across assembly measurements come from the surrounding
compiled measurement code; the assembly object itself is unchanged.

Implementation section sizes from `size -A`, excluding harness and debug data:

| Implementation | .text | .rodata | .data | .bss |
| --- | ---: | ---: | ---: | ---: |
| C O1 | 140 | 0 | 0 | 0 |
| C O2 | 140 | 0 | 0 | 0 |
| C O3 | 140 | 0 | 0 | 0 |
| C Os | 120 | 0 | 0 | 0 |
| Assembly | 132 | 0 | 0 | 0 |

The assembly is 8 bytes smaller than the fastest C build, but 12 bytes larger
than the smallest C build. Duplicating the normalization paths trades code
size for fewer operand moves and faster execution.

## Applications

Binary GCD is useful for reducing rational numbers and integer ratios on
small processors without a hardware divider. Its shifts and subtraction map
directly to RV32I, and its constant storage cost suits a small bare-metal
stack. Its data-dependent branches and iteration count mean this version
is not a constant-time implementation for secret operands.

## Reproduce

```bash
cd /home/edison/arch2026-progs
source /home/edison/arch2026-lab2/setenv
make build/host/gcd
build/host/gcd
make dump neg
scripts/driver.py --prog gcd
```
