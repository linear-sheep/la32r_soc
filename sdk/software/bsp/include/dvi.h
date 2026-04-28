#ifndef DVI_H
#define DVI_H
#include "common_func.h"

// DVI 模块的基地址
#define DVI_BASEADDR 0xbf100000
// DMA 模块的基地址 (配置 SOBEL 和 FB)
#define DMA_BASEADDR 0xbf300000

#define DVI_RECT_DIR (DVI_BASEADDR + 0x0)

#define DVI_RECT_L_W (DVI_BASEADDR + 0x4)

#define DVI_SQU_DIR (DVI_BASEADDR + 0x8)

#define DVI_SQU_R (DVI_BASEADDR + 0xC)

// VRAM 控制寄存器 (现在属于 DMA 模块的寄存器空间)
#define DMA_VRAM_BASE_ADDR  (DMA_BASEADDR + 0x10)
#define DMA_VRAM_CTRL       (DMA_BASEADDR + 0x14)

// draw rect on DVI to x y 
void DVI_Draw_Rect(uint32_t x, uint32_t y, uint32_t l, uint32_t w);

// draw squ on DVI to x y r
void DVI_Draw_SQU(uint32_t x, uint32_t y, uint32_t r);

// 显存层控制接口
void DVI_SetVramBase(uint32_t base_addr);
void DVI_EnableVram(uint32_t en);

#endif // DVI
