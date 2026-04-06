#include <stdio.h> 
#include <stdlib.h>

#include "common_func.h"
#include "dvi.h"
#include "core_time.h"

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
        RegWrite(0xbf20f00c, int_state & 0xf);
    }
}