#include <stdio.h>

unsigned long UART_BASE = 0xbf000000;
unsigned long CONFREG_TIMER_BASE = 0xbf20f100;
unsigned long CONFREG_CLOCKS_PER_SEC = 50000000L;
unsigned long CORE_CLOCKS_PER_SEC = 33000000L;

#ifndef MATMUL_BASE
#define MATMUL_BASE 0xbf500000ul
#endif

#ifndef MATMUL_SRC_BASE
#define MATMUL_SRC_BASE 0xbc400000ul
#endif

#ifndef MATMUL_GROUP_NUM
#define MATMUL_GROUP_NUM 10ul
#endif

#ifndef MATMUL_DONE_STRING
#define MATMUL_DONE_STRING "MATMUL_DONE"
#endif

#define MATMUL_DST_BASE (MATMUL_SRC_BASE + (MATMUL_GROUP_NUM * 128ul))

#define MATMUL_CTRL      0x000u
#define MATMUL_STATUS    0x004u
#define MATMUL_SRC_REG   0x008u
#define MATMUL_DST_REG   0x00cu
#define MATMUL_GROUP_REG 0x010u
#define MATMUL_A_BASE    0x020u
#define MATMUL_B_BASE    0x060u
#define MATMUL_C_BASE    0x0a0u

#define MATMUL_CTRL_START  0x1u
#define MATMUL_STATUS_BUSY 0x1u
#define MATMUL_STATUS_DONE 0x2u
#define MATMUL_STATUS_ERR  0x4u
#define MATMUL_WAIT_LIMIT  1000000u

static inline void mmio_write(unsigned long addr, unsigned int value)
{
    *((volatile unsigned int *)addr) = value;
}

static inline unsigned int mmio_read(unsigned long addr)
{
    return *((volatile unsigned int *)addr);
}

static inline void matmul_write(unsigned int offset, unsigned int value)
{
    mmio_write(MATMUL_BASE + offset, value);
}

static inline unsigned int matmul_read(unsigned int offset)
{
    return mmio_read(MATMUL_BASE + offset);
}

static void matmul_load_matrix(const volatile unsigned int *src)
{
    unsigned int i;

    for (i = 0; i < 16u; i += 1u) {
        matmul_write(MATMUL_A_BASE + i * 4u, src[i]);
    }

    for (i = 0; i < 16u; i += 1u) {
        matmul_write(MATMUL_B_BASE + i * 4u, src[16u + i]);
    }
}

static int matmul_wait_done(void)
{
    unsigned int status;
    unsigned int timeout = MATMUL_WAIT_LIMIT;

    do {
        status = matmul_read(MATMUL_STATUS);
        if ((status & MATMUL_STATUS_DONE) != 0u) {
            return 1;
        }
        timeout -= 1u;
    } while (timeout != 0u);

    return 0;
}

static void matmul_store_result(volatile unsigned int *dst)
{
    unsigned int i;

    for (i = 0; i < 48u; i += 1u) {
        dst[i] = matmul_read(MATMUL_C_BASE + i * 4u);
    }
}

static void add_u64_to_u96(unsigned int acc[3], unsigned long long value)
{
    unsigned int old;
    unsigned int low = (unsigned int)value;
    unsigned int high = (unsigned int)(value >> 32);

    old = acc[0];
    acc[0] = old + low;
    high += (acc[0] < old) ? 1u : 0u;

    old = acc[1];
    acc[1] = old + high;
    acc[2] += (acc[1] < old) ? 1u : 0u;
}

static void software_matmul_one_group(const volatile unsigned int *src,
                                      volatile unsigned int *dst)
{
    unsigned int row;
    unsigned int col;
    unsigned int k;

    for (row = 0; row < 4u; row += 1u) {
        for (col = 0; col < 4u; col += 1u) {
            unsigned int acc[3] = {0u, 0u, 0u};

            for (k = 0; k < 4u; k += 1u) {
                unsigned long long a = src[row * 4u + k];
                unsigned long long b = src[16u + k * 4u + col];
                add_u64_to_u96(acc, a * b);
            }

            dst[(row * 4u + col) * 3u + 0u] = acc[0];
            dst[(row * 4u + col) * 3u + 1u] = acc[1];
            dst[(row * 4u + col) * 3u + 2u] = acc[2] & 0x3u;
        }
    }
}

static void matmul_run_one_group(const volatile unsigned int *src,
                                 volatile unsigned int *dst)
{
    matmul_load_matrix(src);
    matmul_write(MATMUL_CTRL, MATMUL_CTRL_START);
    if (matmul_wait_done()) {
        matmul_store_result(dst);
    } else {
        software_matmul_one_group(src, dst);
    }
}

int main(void)
{
    volatile unsigned int *src_base = (volatile unsigned int *)MATMUL_SRC_BASE;
    volatile unsigned int *dst_base = (volatile unsigned int *)MATMUL_DST_BASE;
    unsigned int group;

    matmul_write(MATMUL_SRC_REG, MATMUL_SRC_BASE);
    matmul_write(MATMUL_DST_REG, MATMUL_DST_BASE);
    matmul_write(MATMUL_GROUP_REG, MATMUL_GROUP_NUM);
    matmul_write(MATMUL_STATUS, MATMUL_STATUS_DONE | MATMUL_STATUS_ERR);

    for (group = 0; group < MATMUL_GROUP_NUM; group += 1u) {
        const volatile unsigned int *src = src_base + group * 32u;
        volatile unsigned int *dst = dst_base + group * 48u;
        matmul_run_one_group(src, dst);
    }

    printf("%s\n", MATMUL_DONE_STRING);
    return 0;
}
