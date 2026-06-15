#include <stdio.h>
#include <stdlib.h>
#include "common_func.h"
#include "matrix_mul.h"

// BSP globals
unsigned long UART_BASE = 0xbf000000;
unsigned long CONFREG_TIMER_BASE = 0xbf20f100;
unsigned long CONFREG_CLOCKS_PER_SEC = 50000000L;
unsigned long CORE_CLOCKS_PER_SEC = 33000000L;

// Expected C = A * B for 4x4 identity-like test
// A = [[1,2,3,4], [5,6,7,8], [9,10,11,12], [13,14,15,16]]
// B = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]]
// C should = A
static const uint32_t A[16] = {
    1, 2, 3, 4,
    5, 6, 7, 8,
    9, 10, 11, 12,
    13, 14, 15, 16
};

static const uint32_t B[16] = {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
};

static int verify_result(const uint32_t c_hw[48])
{
    int errors = 0;
    int r, c;
    printf("[VERIFY] Checking C = A * B ...\n");

    for (r = 0; r < 4; r++) {
        for (c = 0; c < 4; c++) {
            // Expected: C[r][c] = A[r][c] (since B = identity)
            uint64_t expected = A[r * 4 + c];
            // Read 66-bit result from 3 words
            uint32_t lo  = c_hw[(r * 4 + c) * 3 + 0];
            uint32_t mid = c_hw[(r * 4 + c) * 3 + 1];
            uint32_t hi  = c_hw[(r * 4 + c) * 3 + 2];
            uint64_t result = ((uint64_t)(hi & 0x3) << 64) |
                              ((uint64_t)mid << 32) | lo;

            if (result != expected) {
                printf("[FAIL] C[%d][%d] = 0x%08x%08x (hi=%d), expected 0x%08x\n",
                       r, c, (unsigned int)(result >> 32), (unsigned int)result,
                       hi & 0x3, (unsigned int)expected);
                errors++;
            }
        }
    }
    if (errors == 0) {
        printf("[PASS] All 16 elements correct.\n");
    }
    return errors;
}

int main(int argc, char **argv)
{
    uint32_t c_result[48];
    int i;

    printf("Matrix Multiplication Test (4x4) Start...\n");

    // Step 1: Write A and B to IP registers
    printf("[STEP] Writing matrix A...\n");
    matrix_mul_write_a(A);

    printf("[STEP] Writing matrix B...\n");
    matrix_mul_write_b(B);

    // Step 2: Start computation
    printf("[STEP] Starting computation...\n");
    matrix_mul_start();

    // Step 3: Wait for done
    printf("[STEP] Waiting for completion...\n");
    matrix_mul_wait_done();
    printf("[STEP] Computation done!\n");

    // Step 4: Read results
    printf("[STEP] Reading result matrix C...\n");
    matrix_mul_read_c(c_result);

    // Step 5: Print results
    printf("[RESULT] Matrix C (66-bit elements, hi:mid:lo):\n");
    for (i = 0; i < 16; i++) {
        uint32_t lo  = c_result[i * 3 + 0];
        uint32_t mid = c_result[i * 3 + 1];
        uint32_t hi  = c_result[i * 3 + 2];
        printf("  C[%d][%d] = %02x:%08x:%08x\n",
               i / 4, i % 4, hi & 0x3, mid, lo);
    }

    // Step 6: Verify
    int errors = verify_result(c_result);

    printf("\n====================\n");
    if (errors == 0) {
        printf("Matrix Test: PASSED\n");
    } else {
        printf("Matrix Test: FAILED (%d errors)\n", errors);
    }
    printf("====================\n");

    return 0;
}

void HWI0_IntrHandler(void)
{
    unsigned int int_state = RegRead(0xbf20f014);
    if ((int_state & 0x10) == 0x10) {
        RegWrite(0xbf20f108, 0);
        RegWrite(0xbf20f108, 1);
    } else if (int_state & 0xf) {
        RegWrite(0xbf20f00c, int_state & 0xf);
    }
}
