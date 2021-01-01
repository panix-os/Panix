#include <stddef.h>

#include <lib/bitmap.hpp>
#include <lib/stdio.hpp>
#include <sys/tasks.hpp>
#include <apps/primes.hpp>

// this value can be tweaked based on memory constraints
#define PRIME_MAX_SQRT 4000
#define PRIME_MAX (PRIME_MAX_SQRT * PRIME_MAX_SQRT)
#define PRIMES_SIZE BITMAP_SIZE(PRIME_MAX)
static bitmap_t primes[PRIMES_SIZE];

static size_t prime_current;

void find_primes(void)
{
    for (size_t i = 0; i < PRIMES_SIZE; i++)
        primes[i] = SIZE_T_MAX_VALUE;

    for (prime_current = 2; prime_current < PRIME_MAX_SQRT; prime_current++) {
        if (!bitmap_get_bit(primes, prime_current)) continue;
        for (size_t j = prime_current * prime_current; j < PRIME_MAX; j += prime_current) {
            bitmap_clear_bit(primes, j);
        }
//        px_tasks_nano_sleep(1000ULL * 1000 * 100);
    }
}

void show_primes(void)
{
    do {
        px_tasks_nano_sleep(1000ULL * 1000);
        size_t pct = (prime_current * 100) / PRIME_MAX_SQRT;
        px_kprintf("\e[s\e[23;0fComputing primes: %%%u\e[u", pct);
    } while (prime_current < PRIME_MAX_SQRT);

    size_t count = 0;
    for (size_t i = 2; i < PRIME_MAX; i++) {
        count += bitmap_get_bit(primes, i);
    }
    px_kprintf("\e[s\e[23;0fFound %u primes between 2 and %u.\e[u", count, PRIME_MAX);
}
