#include "gcd.h"

/* Stein's algorithm: remove common powers of two, then reduce odd operands.
 * All arithmetic is unsigned, and every shift count is below 32.
 */
uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    if (!a)
        return b;
    if (!b)
        return a;

    unsigned shift = 0;
    while (((a | b) & 1u) == 0) {
        a >>= 1;
        b >>= 1;
        shift++;
    }
    while ((a & 1u) == 0)
        a >>= 1;

    do {
        while ((b & 1u) == 0)
            b >>= 1;
        if (a > b) {
            uint32_t tmp = a;
            a = b;
            b = tmp;
        }
        b -= a;
    } while (b);

    return a << shift;
}
