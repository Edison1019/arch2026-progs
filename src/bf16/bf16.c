#include "bf16.h"

uint16_t bf16_from_f32(uint32_t bits)
{
    if (((bits >> 23) & 255u) == 255u)
        return (uint16_t) (bits >> 16);
    return (uint16_t) ((bits + 0x7FFFu + ((bits >> 16) & 1u)) >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint32_t sign = (a ^ b) & 0x8000u;
    int ea = (a >> 7) & 255, eb = (b >> 7) & 255;
    uint32_t ma = a & 127u, mb = b & 127u;

    /* Preserve the contract's operand order, including Inf times NaN. */
    if (ea == 255) {
        if (ma)
            return a;
        if ((b & 0x7FFFu) == 0)
            return 0x7FC0;
        return (uint16_t) (sign | 0x7F80u);
    }
    if (eb == 255) {
        if (mb)
            return b;
        if ((a & 0x7FFFu) == 0)
            return 0x7FC0;
        return (uint16_t) (sign | 0x7F80u);
    }
    if (((a & 0x7FFFu) == 0) || ((b & 0x7FFFu) == 0))
        return (uint16_t) sign;

    if (ea)
        ma |= 128u;
    else {
        ea = 1;
        while (ma < 128u) {
            ma <<= 1;
            ea--;
        }
    }
    if (eb)
        mb |= 128u;
    else {
        eb = 1;
        while (mb < 128u) {
            mb <<= 1;
            eb--;
        }
    }

    uint32_t product = ma * mb;
    int exponent = ea + eb - 127;
    if (product >= 32768u) {
        product >>= 1;
        exponent++;
    }
    uint32_t mantissa = product >> 7;
    if (exponent >= 255)
        return (uint16_t) (sign | 0x7F80u);
    if (exponent <= 0) {
        if (exponent < -6)
            return (uint16_t) sign;
        return (uint16_t) (sign | ((mantissa & 127u) >> (1 - exponent)));
    }
    return (uint16_t) (sign | ((uint32_t) exponent << 7) | (mantissa & 127u));
}

uint16_t bf16_sqrt(uint16_t a)
{
    uint32_t exponent = (a >> 7) & 255u;
    uint32_t mantissa = a & 127u;
    if ((exponent == 255u) && mantissa)
        return a;
    if ((a & 0x7FFFu) == 0)
        return 0;
    if (a & 0x8000u)
        return 0x7FC0;
    if (exponent == 255u)
        return a;
    if (!exponent)
        return 0;

    mantissa |= 128u;
    /* The unbiased exponent is odd exactly when the biased one is even. */
    if ((exponent & 1u) == 0)
        mantissa <<= 1;
    exponent = (exponent + 127u) >> 1;

    /* floor(mid*mid/128) <= m iff mid*mid <= 128*(m+1)-1.
     * Restoring integer square root uses eight base-four steps, no multiply.
     */
    uint32_t remainder = (mantissa << 7) + 127u, root = 0;
    for (uint32_t bit = 1u << 14; bit; bit >>= 2) {
        uint32_t trial = root + bit;
        root >>= 1;
        if (remainder >= trial) {
            remainder -= trial;
            root += bit;
        }
    }
    return (uint16_t) ((exponent << 7) | (root & 127u));
}
