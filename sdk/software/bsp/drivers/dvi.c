#include "dvi.h"

// 设置坐标和颜色的绘图函数
void DVI_Draw_Rect(uint32_t x, uint32_t y, uint32_t l, uint32_t w)
{
    uint32_t coordinates = ((x & 0xFFFF)<<16) | (y & 0xFFFF);
    uint32_t size = ((l & 0xFFFF)<<16) | (w & 0xFFFF);
    RegWrite(DVI_RECT_DIR, coordinates);
    RegWrite(DVI_RECT_L_W, size);
}

void DVI_Draw_SQU(uint32_t x, uint32_t y, uint32_t r)
{
    uint32_t coordinates = ((x & 0xFFFF)<<16) | (y & 0xFFFF);
    uint32_t size = ((r & 0xFFFF)<<16) | (r & 0xFFFF);
    RegWrite(DVI_SQU_DIR, coordinates);
    RegWrite(DVI_SQU_R, size);
}

void DVI_SetVramBase(uint32_t base_addr)
{
    RegWrite(DVI_VRAM_BASE_ADDR, base_addr);
}

void DVI_EnableVram(uint32_t en)
{
    RegWrite(DVI_VRAM_CTRL, (en & 0x1));
}
