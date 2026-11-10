#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;
    while (b) {
        uint32_t carry = (a & b) << 1;
        a ^= b;
        b = carry;
        passes++;
    }
    *n = passes;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    /* a + b = 2 * (a & b) + (a ^ b), without forming the sum. */
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t x = (uint32_t) a, y = (uint32_t) b;
    uint32_t correction = (a < 0 ? y : 0) + (b < 0 ? x : 0);
    uint32_t high = 0, low = 1u << (Q - 1), x_high = 0;

    /* Form an unsigned product plus the rounding bias in a register pair.
     * Signed multiplication differs only in the high word correction.
     */
    while (y) {
        if (y & 1u) {
            uint32_t old = low;
            low += x;
            high += x_high + (low < old);
        }
        x_high = (x_high << 1) | (x >> 31);
        x <<= 1;
        y >>= 1;
    }
    high -= correction;
    uint32_t result = (low >> Q) | (high << (32 - Q));

    /* Reinterpret the result without an out-of-range unsigned-to-signed
     * conversion. Only the low 32 bits of the shifted product are required.
     */
    if (result <= INT32_MAX)
        return (int32_t) result;
    return -1 - (int32_t) ~result;
}
