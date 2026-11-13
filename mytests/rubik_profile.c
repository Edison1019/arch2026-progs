/* Additional hard-state verification using the independent public test model.
 * These files are outside src/ and are not part of the submitted solver.
 */
#include "../tests/trubik.c"
#include "rubik_cases.h"
static uint64_t worst_c, worst_asm;
static unsigned index_c, index_asm, current;
static int timed_c(const char *state, char *out, size_t cap)
{
    uint64_t used;
    int n;
    PERF_CALL(used, n = rubik_solve(state, out, cap));
    if (used > worst_c) {
        worst_c = used;
        index_c = current;
    }
    if (used > RUBIK_C_INSN_BUDGET)
        return -1;
    return n;
}
static int timed_asm(const char *state, char *out, size_t cap)
{
    uint64_t used;
    int n;
    PERF_CALL(used, n = rubik_solve_asm(state, out, cap));
    if (used > worst_asm) {
        worst_asm = used;
        index_asm = current;
    }
    if (used > RUBIK_INSN_BUDGET)
        return -1;
    return n;
}
int main(void)
{
    unsigned count = sizeof(profile_cases) / sizeof(profile_cases[0]);
    for (current = 0; current < count; current++) {
        int n;
        const struct profile_case *c = &profile_cases[current];
        if (solve_and_verify(timed_c, c->state, &n) != TEST_PASS ||
            n != c->distance)
            return 1;
        if (solve_and_verify(timed_asm, c->state, &n) != TEST_PASS ||
            n != c->distance)
            return 2;
    }
    utest_printer("profile cases=%u C worst=%llu at %s ASM worst=%llu at %s\n",
                  count, worst_c, profile_cases[index_c].state, worst_asm,
                  profile_cases[index_asm].state);
    return 0;
}
