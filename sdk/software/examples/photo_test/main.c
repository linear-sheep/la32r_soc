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

// BSP 所需全局变量
unsigned long UART_BASE = 0xbf000000;
unsigned long CONFREG_TIMER_BASE = 0xbf20f100;
unsigned long CONFREG_CLOCKS_PER_SEC = 50000000L;
unsigned long CORE_CLOCKS_PER_SEC = 33000000L;


static void photo_test(void)
{
    volatile unsigned char *fb0 = (volatile unsigned char *)(VRAM_CPU_BASE);
    int x_off = (WIDTH - IMG_W) / 2;
    int y_off = (HEIGHT - IMG_H) / 2;

    // 清零背景
    for (int i = 0; i < FRAME_BYTES; i++) {
        fb0[i] = 0;
    }

    // 将 400x300 的图片数据复制到 800x600 显存中央
    for (int y = 0; y < IMG_H; y++) {
        for (int x = 0; x < IMG_W; x++) {
            int dst_x = x + x_off;
            int dst_y = y + y_off;

            if (dst_x >= 0 && dst_x < WIDTH && dst_y >= 0 && dst_y < HEIGHT) {
                // fb0 每行是 800 像素，image_data 每行是 400 像素
                fb0[dst_y * WIDTH + dst_x] = image_data[y * IMG_W + x];
            }
        }
    }

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
