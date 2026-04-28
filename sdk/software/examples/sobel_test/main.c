#include <stdio.h>
#include <stdlib.h>

#include "common_func.h"
#include "dvi.h"
#include "core_time.h"
#include "image.h"

#define FPS   30
#define WIDTH 800
#define HEIGHT 600

// 这里定义我们在 convert.py 里设定生成的图片大小
#define IMG_W 400
#define IMG_H 300

#define FRAME_PIXELS (WIDTH * HEIGHT)
#define FRAME_BYTES  (FRAME_PIXELS) 

#define VRAM_CPU_BASE  0xbc400000u
#define VRAM0_PHYS     0x1c400000u

#define SOBEL_BASE      0xbf300000
#define SOBEL_SRC_ADDR  (*(volatile unsigned int *)(SOBEL_BASE + 0x00))
#define SOBEL_DST_ADDR  (*(volatile unsigned int *)(SOBEL_BASE + 0x04))
#define SOBEL_CTRL      (*(volatile unsigned int *)(SOBEL_BASE + 0x08)) // [0] Start (W), [0] Done (R)
#define SOBEL_DIM       (*(volatile unsigned int *)(SOBEL_BASE + 0x0C)) // [31:16] Height, [15:0] Width

// BSP 所需全局变量
unsigned long UART_BASE = 0xbf000000;
unsigned long CONFREG_TIMER_BASE = 0xbf20f100;
unsigned long CONFREG_CLOCKS_PER_SEC = 50000000L;
unsigned long CORE_CLOCKS_PER_SEC = 33000000L;


static void photo_test(void)
{
    // 双缓冲：目标显存 (0x1c400000) 负责输出到 DVI，源显存 (0x1c400000 + 一帧大小) 负责存放原图
    volatile unsigned char *fb_dst = (volatile unsigned char *)(VRAM_CPU_BASE);
    volatile unsigned char *fb_src = (volatile unsigned char *)(VRAM_CPU_BASE + FRAME_BYTES);
    
    int x_off = (WIDTH - IMG_W) / 2;
    int y_off = (HEIGHT - IMG_H) / 2;

    printf("[DEBUG] Clearing background...\n");

    // 清零目标和源背景
    for (int i = 0; i < FRAME_BYTES; i++) {
        fb_dst[i] = 0;
        fb_src[i] = 0;
    }

    printf("[DEBUG] Copying image to VRAM...\n");

    // 1. 将原图布置到 VRAM 源地址处 (居中)
    for (int y = 0; y < IMG_H; y++) {
        for (int x = 0; x < IMG_W; x++) {
            int dst_x = x + x_off;
            int dst_y = y + y_off;
            if (dst_x >= 0 && dst_x < WIDTH && dst_y >= 0 && dst_y < HEIGHT) {
                fb_src[dst_y * WIDTH + dst_x] = image_data[y * IMG_W + x];
            }
        }
    }

    printf("[DEBUG] Configuring DMA...\n");
    __asm__ volatile("sync" ::: "memory"); // 强制刷新 CPU 缓存/写缓冲

    // 2. 配置 Sobel 硬件 DMA 算子进行处理
    SOBEL_SRC_ADDR = VRAM0_PHYS + FRAME_BYTES;
    SOBEL_DST_ADDR = VRAM0_PHYS;
    SOBEL_DIM      = (HEIGHT << 16) | WIDTH;
    
    // 启动硬件计算
    SOBEL_CTRL     = 1;
    printf("[DEBUG] DMA Start. Waiting for completion...\n");
    
    // 轮询等待硬件计算完成 (假设硬件在算完后将位 0 置 1)
    while ((SOBEL_CTRL & 1) == 0) {
        // do nothing
    }
    printf("[DEBUG] DMA Finish.\n");

    // 3. 将 DVI 显存基址指向处理完毕的目标地址
    DVI_Draw_Rect(0, 0, 0, 0);
    DVI_Draw_SQU(0, 0, 0);

    DVI_SetVramBase(VRAM0_PHYS);
    DVI_EnableVram(1);

    while (1) {
        // 不需要每帧重绘，保持不变即可
        delay_ms(100);
    }
}

int main(int argc, char **argv)
{
    printf("Start Photo VRAM DVI test...\n");
    photo_test();
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
