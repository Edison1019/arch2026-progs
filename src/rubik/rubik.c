/* Coordinates and parser adapted from Edison1019/minirubik.
 * See LICENSE.minirubik. Search uses a bounded meet-in-the-middle frontier.
 */
#include "rubik.h"
#include "pdb_tables.h"
#include "search_tables.h"

enum { CUBIES = 7, MAX_DEPTH = 11 };
static const uint8_t face_of[9] = {0, 0, 0, 1, 1, 1, 2, 2, 2};
static const uint8_t turns_of[9] = {1, 2, 3, 1, 2, 3, 1, 2, 3};

static unsigned heuristic(unsigned p, unsigned o)
{
    unsigned hp = pdb_permutation[p], ho = pdb_orientation[o];
    return hp > ho ? hp : ho;
}

static uint32_t near_lookup(unsigned p, unsigned o)
{
    uint32_t key = (p << 10) | o;
    unsigned hash = (key ^ (key >> 10) ^ (key >> 16)) & 65535u;
    if (((rubik_bloom[hash >> 5] >> (hash & 31)) & 1u) == 0)
        return 0;
    unsigned low = 0, high = 12224;
    while (low < high) {
        unsigned mid = (low + high) >> 1;
        uint32_t entry = rubik_near[mid], found = entry >> 7;
        if (found == key)
            return entry;
        if (found < key)
            low = mid + 1;
        else
            high = mid;
    }
    return 0;
}

static int finish(unsigned p, unsigned o, uint8_t *path, uint32_t entry)
{
    int length = (int) ((entry >> 4) & 7u);
    for (int i = 0; i < length; i++) {
        unsigned move = entry & 15u, face = face_of[move];
        path[i] = (uint8_t) move;
        for (unsigned t = 0; t < turns_of[move]; t++) {
            p = perm_trans[p][face];
            o = ori_trans[o][face];
        }
        entry = near_lookup(p, o);
    }
    return length;
}

/* At most six recursive edges: the final five moves come from the table.
 * The heuristic is admissible and adjacent turns on one face are redundant.
 */
static int search(unsigned p,
                  unsigned o,
                  unsigned remaining,
                  unsigned last,
                  uint8_t *path)
{
    if (heuristic(p, o) > remaining)
        return -1;
    if (remaining <= 5) {
        uint32_t entry = near_lookup(p, o);
        if (!entry || ((entry >> 4) & 7u) > remaining)
            return -1;
        return finish(p, o, path, entry);
    }
    for (unsigned face = 0; face < 3; face++) {
        if (face == last)
            continue;
        unsigned np = p, no = o;
        for (unsigned t = 0; t < 3; t++) {
            np = perm_trans[np][face];
            no = ori_trans[no][face];
            int n = search(np, no, remaining - 1, face, path + 1);
            if (n >= 0) {
                path[0] = (uint8_t) (face * 3 + t);
                return n + 1;
            }
        }
    }
    return -1;
}

static int solve(unsigned p, unsigned o, uint8_t *path)
{
    uint32_t entry = near_lookup(p, o);
    if (entry)
        return finish(p, o, path, entry);
    uint32_t key = (p << 10) | o;
    unsigned low = 0, high = 2644;
    int at_diameter = 0;
    while (low < high) {
        unsigned mid = (low + high) >> 1;
        uint32_t found = rubik_diameter[mid];
        if (found == key) {
            at_diameter = 1;
            break;
        }
        if (found < key)
            low = mid + 1;
        else
            high = mid;
    }
    unsigned bound = at_diameter ? 11 : heuristic(p, o);
    if (bound < 6)
        bound = 6;
    for (; bound <= (at_diameter ? 11u : 10u); bound++) {
        int n = search(p, o, bound, 3, path);
        if (n >= 0)
            return n;
    }
    return -1;
}

typedef struct {
    uint8_t p[CUBIES], o[CUBIES];
} state_t;

static void rank_state(const state_t *state, uint16_t *pr, uint16_t *orank)
{
    uint32_t p = 0, o = 0;
    for (unsigned i = 0; i < CUBIES; ++i) {
        unsigned smaller = 0;
        for (unsigned j = i + 1; j < CUBIES; ++j)
            smaller += state->p[j] < state->p[i];
        p = p * (CUBIES - i) + smaller;
    }
    for (unsigned i = 0; i < CUBIES - 1; ++i)
        o = o * 3 + state->o[i];
    *pr = (uint16_t) p;
    *orank = (uint16_t) o;
}

static int parse_state(const char *input, state_t *state)
{
    unsigned seen = 0, sum = 0;
    for (unsigned i = 0; i < 2 * CUBIES; ++i) {
        unsigned char c = (unsigned char) input[i];
        if (c < '1' || c > (i < CUBIES ? '7' : '3'))
            return 0;
        if (i < CUBIES) {
            unsigned bit = 1U << (c - '1');
            if (seen & bit)
                return 0;
            seen |= bit;
            state->p[i] = (uint8_t) (c - '1');
        } else {
            state->o[i - CUBIES] = (uint8_t) (c - '1');
            sum += c - '1';
        }
    }
    return input[2 * CUBIES] == '\0' &&
           (sum == 0 || sum == 3 || sum == 6 || sum == 9 || sum == 12);
}


int rubik_solve(const char *input, char *out, size_t cap)
{
    state_t state;
    uint8_t path[MAX_DEPTH];
    uint16_t p, o;
    if (!parse_state(input, &state))
        return -1;
    rank_state(&state, &p, &o);
    int n = solve(p, o, path);
    if (n < 0)
        return -1;
    static const char faces[] = "RBD";
    static const char suffix[9] = {0, '2', 39, 0, '2', 39, 0, '2', 39};
    size_t needed = 1;
    for (int i = 0; i < n; ++i)
        needed += 1u + (suffix[path[i]] != 0) + (i != 0);
    if (cap < needed) {
        if (cap)
            out[0] = 0;
        return -2;
    }
    char *dst = out;
    for (int i = 0; i < n; ++i) {
        if (i)
            *dst++ = ' ';
        *dst++ = faces[face_of[path[i]]];
        if (suffix[path[i]])
            *dst++ = suffix[path[i]];
    }
    *dst = 0;
    return n;
}
