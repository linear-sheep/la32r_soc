<<<<<<< HEAD
#ifndef DVI_H
#define DVI_H
#include "common_func.h"

#define DVI_BASEADDR 0xbf100000

#define DVI_RECT_DIR (DVI_BASEADDR + 0x0)

#define DVI_RECT_L_W (DVI_BASEADDR + 0x4)

#define DVI_SQU_DIR (DVI_BASEADDR + 0x8)

#define DVI_SQU_R (DVI_BASEADDR + 0xC)

// VRAM 控制寄存器
#define DVI_VRAM_BASE_ADDR  (DVI_BASEADDR + 0x10)
#define DVI_VRAM_CTRL       (DVI_BASEADDR + 0x14)

// draw rect on DVI to x y 
void DVI_Draw_Rect(uint32_t x, uint32_t y, uint32_t l, uint32_t w);

// draw squ on DVI to x y r
void DVI_Draw_SQU(uint32_t x, uint32_t y, uint32_t r);

// 显存层控制接口
void DVI_SetVramBase(uint32_t base_addr);
void DVI_EnableVram(uint32_t en);

#endif // DVI
=======
#ifndef DVI_H
#define DVI_H
#include "common_func.h"

#define DVI_BASEADDR 0xbf100000

#define DVI_RECT_DIR (DVI_BASEADDR + 0x0)

#define DVI_RECT_L_W (DVI_BASEADDR + 0x4)

#define DVI_SQU_DIR (DVI_BASEADDR + 0x8)

#define DVI_SQU_R (DVI_BASEADDR + 0xC)

// draw rect on DVI to x y 
void DVI_Draw_Rect(uint32_t x, uint32_t y, uint32_t l, uint32_t w);

// draw squ on DVI to x y r
void DVI_Draw_SQU(uint32_t x, uint32_t y, uint32_t r);

#endif // DVI
>>>>>>> 24239978e32911e879e9238771ec3dc3ffe7820d
