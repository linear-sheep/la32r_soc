#ifndef MATRIX_MUL_H
#define MATRIX_MUL_H
#include "common_func.h"

// AXI4 virtual base (DMW1: 0xBF500000 -> physical 0x1F500000)
#define MATRIX_MUL_BASEADDR  0xbf500000

// Register offsets (byte addresses)
#define MATRIX_CTRL           (MATRIX_MUL_BASEADDR + 0x00)
#define MATRIX_STATUS         (MATRIX_MUL_BASEADDR + 0x04)
#define MATRIX_SRC_BASE       (MATRIX_MUL_BASEADDR + 0x08)
#define MATRIX_DST_BASE       (MATRIX_MUL_BASEADDR + 0x0C)
#define MATRIX_GROUP_NUM      (MATRIX_MUL_BASEADDR + 0x10)
#define MATRIX_A_DATA_BASE    (MATRIX_MUL_BASEADDR + 0x20)
#define MATRIX_B_DATA_BASE    (MATRIX_MUL_BASEADDR + 0x60)
#define MATRIX_C_DATA_BASE    (MATRIX_MUL_BASEADDR + 0xA0)

// CTRL bits
#define MATRIX_CTRL_START     0x00000001

// STATUS bits
#define MATRIX_STATUS_BUSY    0x00000001
#define MATRIX_STATUS_DONE    0x00000002

// Matrix dimensions
#define MATRIX_DIM            4
#define MATRIX_A_SIZE         16
#define MATRIX_B_SIZE         16
#define MATRIX_C_SIZE         48

// Driver API
void matrix_mul_write_a(const uint32_t a[MATRIX_A_SIZE]);
void matrix_mul_write_b(const uint32_t b[MATRIX_B_SIZE]);
void matrix_mul_start(void);
int  matrix_mul_is_done(void);
void matrix_mul_wait_done(void);
void matrix_mul_read_c(uint32_t c[MATRIX_C_SIZE]);

#endif // MATRIX_MUL_H
