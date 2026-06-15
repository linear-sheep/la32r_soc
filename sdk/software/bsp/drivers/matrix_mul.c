#include "matrix_mul.h"

void matrix_mul_write_a(const uint32_t a[MATRIX_A_SIZE])
{
    int i;
    for (i = 0; i < MATRIX_A_SIZE; i++) {
        RegWrite(MATRIX_A_DATA_BASE + (i << 2), a[i]);
    }
}

void matrix_mul_write_b(const uint32_t b[MATRIX_B_SIZE])
{
    int i;
    for (i = 0; i < MATRIX_B_SIZE; i++) {
        RegWrite(MATRIX_B_DATA_BASE + (i << 2), b[i]);
    }
}

void matrix_mul_start(void)
{
    RegWrite(MATRIX_CTRL, MATRIX_CTRL_START);
}

int matrix_mul_is_done(void)
{
    return (RegRead(MATRIX_STATUS) & MATRIX_STATUS_DONE) ? 1 : 0;
}

void matrix_mul_wait_done(void)
{
    while (!matrix_mul_is_done());
}

void matrix_mul_read_c(uint32_t c[MATRIX_C_SIZE])
{
    int i;
    for (i = 0; i < MATRIX_C_SIZE; i++) {
        c[i] = RegRead(MATRIX_C_DATA_BASE + (i << 2));
    }
}
