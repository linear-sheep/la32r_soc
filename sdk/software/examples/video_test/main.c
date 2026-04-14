<<<<<<< HEAD
#include <stdio.h>
=======
#include <stdio.h> 
>>>>>>> 24239978e32911e879e9238771ec3dc3ffe7820d
#include <stdlib.h>

#include "common_func.h"
#include "dvi.h"
#include "core_time.h"

<<<<<<< HEAD
#define FPS   30
#define N     32
#define WIDTH 800
#define HEIGHT 600

#define FRAME_PIXELS (WIDTH * HEIGHT)
#define FRAME_BYTES  (FRAME_PIXELS) 

// 这里采用双缓存设计，所占空间在 1MB 以内
// CPU 侧写显存用虚地址（uncached 段），对应物理 0x1c400000 (ExtRAM)
#define VRAM_CPU_BASE  0xbc400000u
#define VRAM0_PHYS     0x1c400000u
#define VRAM1_PHYS     (VRAM0_PHYS + FRAME_BYTES)

static unsigned int canvas[N][N];
static int used[N][N];
static int dx[4] = {0, 1, 0, -1};
static int dy[4] = {1, 0, -1, 0};

// BSP 所需全局变量
unsigned long UART_BASE = 0xbf000000;
unsigned long CONFREG_TIMER_BASE = 0xbf20f100;
unsigned long CONFREG_CLOCKS_PER_SEC = 50000000L;
unsigned long CORE_CLOCKS_PER_SEC = 33000000L;

static inline unsigned int pixel(unsigned int r, unsigned int g, unsigned int b)
{
    // 生成并压缩为 8 位 RGB332 值：RRR_GGG_BB
    return ((r & 0xE0) | ((g & 0xE0) >> 3) | ((b & 0xC0) >> 6));
}

static unsigned int p(int tsc)
{
    int b = tsc & 0xff;
    return pixel((b * 6) & 0xff, (b * 7) & 0xff, b);
}

static void update(void)
{
    static int tsc = 0;
    tsc++;

    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            used[i][j] = 0;

    int init = tsc;
    canvas[0][0] = p(init);
    used[0][0] = 1;

    int x = 0, y = 0, d = 0;
    for (int step = 1; step < N * N; step++) {
        for (int t = 0; t < 4; t++) {
            int x1 = x + dx[d];
            int y1 = y + dy[d];
            if (x1 >= 0 && x1 < N && y1 >= 0 && y1 < N && !used[x1][y1]) {
                x = x1;
                y = y1;
                used[x][y] = 1;
                canvas[x][y] = p(init + step / 2);
                break;
            }
            d = (d + 1) & 3;
        }
    }
}

static void redraw(volatile unsigned int *fb)
{
    int w = WIDTH / N;
    int h = HEIGHT / N;
    
    volatile unsigned char *vram_8bit = (volatile unsigned char *)fb;

    int x, y;
    for (y = 0; y < N; y++) {
        for (x = 0; x < N; x++) {
            unsigned char c = (unsigned char)canvas[y][x];
            int x0 = x * w;
            int y0 = y * h;
            for (int py = 0; py < h; py++) {
                int row = (y0 + py) * WIDTH + x0;
                for (int px = 0; px < w; px++) {
                    vram_8bit[row + px] = c;
                }
            }
        }
    }
}

static void video_test(void)
{
    volatile unsigned int *fb0 = (volatile unsigned int *)(VRAM_CPU_BASE);
    volatile unsigned int *fb1 = (volatile unsigned int *)(VRAM_CPU_BASE + FRAME_BYTES);

    int front = 0;
    int back = 1;
    unsigned long frame_id = 0;

    // === 将两帧显存全部清零（黑色），防止底部未整除区域出现随机噪点 ===
    for (int i = 0; i < FRAME_BYTES / 4; i++) {
        fb0[i] = 0;
        fb1[i] = 0;
    }
    // ========================================================

    DVI_Draw_Rect(0, 0, 0, 0);
    DVI_Draw_SQU(0, 0, 0);

    DVI_SetVramBase(VRAM0_PHYS);
    DVI_EnableVram(1);

    while (1) {
        volatile unsigned int *fb = (back == 0) ? fb0 : fb1;
        unsigned int phys = (back == 0) ? VRAM0_PHYS : VRAM1_PHYS;

        update();      // 更新逻辑数据 (canvas)
        redraw(fb);    // 重绘屏幕缓冲区

        // 切前台帧：axi_dvi 会在帧边界锁存，减少撕裂
        DVI_SetVramBase(phys);

        front = back;
        back = 1 - back;
        frame_id++;

        if ((frame_id % FPS) == 0) {
            printf("video frame = %u\n", (unsigned int)frame_id);
        }

        delay_ms(1000 / FPS);
    }
}

int main(int argc, char **argv)
{
    printf("Start VRAM VGA test...\n");
    video_test();
    return 0;
}

void HWI0_IntrHandler(void)
{
    unsigned int int_state = RegRead(0xbf20f014);
    if ((int_state & 0x10) == 0x10) {
        RegWrite(0xbf20f108, 0);
        RegWrite(0xbf20f108, 1);
    } else if (int_state & 0xf) {
=======
#define FPS 30
#define N   32  // 将屏幕划分为 32x32

// ================= 关键缺失补丁 start ================= //
// BSP板级支持包及启动代码(start.S)所强依赖的全局变量
unsigned long UART_BASE              = 0xbf000000;  // UART16550的虚地址
unsigned long CONFREG_TIMER_BASE     = 0xbf20f100;  // CONFREG计数器的虚地址
unsigned long CONFREG_CLOCKS_PER_SEC = 50000000L;   // CONFREG时钟频率
unsigned long CORE_CLOCKS_PER_SEC    = 33000000L;   // 处理器核时钟频率
// ================= 关键缺失补丁 end =================== //

static int used[N][N];
static int dx[4] = {0, 1, 0, -1}; // 行增量
static int dy[4] = {1, 0, -1, 0}; // 列增量

void InterruptInit(void)
{
    // 配置 Confreg 时钟中断等
    RegWrite(0xbf20f004, 0x0f); // edge
    RegWrite(0xbf20f008, 0x1f); // pol
    RegWrite(0xbf20f00c, 0x1f); // clr

    // 0x10 就是只打开 timer 中断，屏蔽 0x0f 的 4个按键干扰
    RegWrite(0xbf20f000, 0x10); 

    RegWrite(0xbf20f104, 25000000); // timercmp 500ms
    RegWrite(0xbf20f108, 0x1);      // timeren
}

int main(int argc, char** argv)
{
    InterruptInit();
    
    // 初始化网格参数
    int grid_x = 0;
    int grid_y = 0;
    int grid_d = 0;
    int step = 0;

    // LA32R SOC 通常 DVI 输出分辨率暂定以 800x600 作为基准逻辑等分
    int w_step = 800 / N; 
    int h_step = 600 / N; 

    // 因为直接进入循环，不再需要 chooseTime
    printf("Starting Video Spiral Test at %d FPS...\n", FPS);

    while (1) {
        // --- 1. 如果走到死胡同或者刚启动，重置这轮螺旋状态 ---
        if (step == 0) {
            for(int i = 0; i < N; i++)
                for(int j = 0; j < N; j++)
                    used[i][j] = 0;
            
            grid_x = 0;
            grid_y = 0;
            grid_d = 0;
            used[0][0] = 1;
            step = 1;
        }

        // --- 2. 渲染当前方块 ---
        // 把 32x32 坐标系转换为实际物理屏幕坐标中心系
        int ScreenX = grid_y * w_step + w_step / 2;
        int ScreenY = grid_x * h_step + h_step / 2;

        DVI_Draw_Rect(0, 0, 0, 0);                 // 关闭矩形绘图
        DVI_Draw_SQU(ScreenX, ScreenY, w_step/2);  // 用正方形作为移动块，大小适应网格

        // --- 3. 帧率控制 ---
        // video.c 的目标频率是 30 fps，间隔就是 1000ms / 30 = 33ms
        delay_ms(1000 / FPS); 

        // --- 4. 状态更新: 探查下一个步应该往哪里走 ---
        if (step < N * N) {
            int moved = 0;
            for (int t = 0; t < 4; t ++) {
                int nx = grid_x + dx[grid_d];
                int ny = grid_y + dy[grid_d];
                
                // 判断下一步是否越界以及是否被占用过
                if (nx >= 0 && nx < N && ny >= 0 && ny < N && !used[nx][ny]) {
                    grid_x = nx; 
                    grid_y = ny; 
                    used[nx][ny] = 1; // 踩下脚迹
                    moved = 1;
                    step++;
                    break;
                }
                // 这条路不通，顺时针变换方向
                grid_d = (grid_d + 1) % 4; 
            }
            // 如果四个方向全不通，说明螺旋已经画满，进入重置
            if (!moved) {
                step = 0; 
            }
        } else {
            step = 0; 
        }
    }

    return 0;
}

// 维持原有的中断处理框架，防止发生异常挂起，但由于我们不监听按钮了可置空业务逻辑
void HWI0_IntrHandler(void)
{	
    unsigned int int_state;
    int_state = RegRead(0xbf20f014);

    if((int_state & 0x10) == 0x10){
        RegWrite(0xbf20f108,0);
        RegWrite(0xbf20f108,1);
    }
    else if(int_state & 0xf){
>>>>>>> 24239978e32911e879e9238771ec3dc3ffe7820d
        RegWrite(0xbf20f00c, int_state & 0xf);
    }
}