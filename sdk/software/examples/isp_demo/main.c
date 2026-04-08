/**
 * ISP Core 演示应用
 * 
 * 功能：
 * - 实时图像处理演示
 * - 支持多种滤波器链式处理
 * - DVI 显示结果
 * - 中断和按钮控制
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "common_func.h"
#include "dvi.h"
#include "isp_driver.h"

// BSP 全局变量
unsigned long UART_BASE = 0xbf000000;
unsigned long CONFREG_TIMER_BASE = 0xbf20f100;
unsigned long CONFREG_CLOCKS_PER_SEC = 50000000L;
unsigned long CORE_CLOCKS_PER_SEC = 33000000L;

// ============================================
// 内存分配
// ============================================

// 图像内存空间（DDR）
#define IMAGE_WIDTH     1280
#define IMAGE_HEIGHT    720
#define IMAGE_SIZE      (IMAGE_WIDTH * IMAGE_HEIGHT)
#define IMAGE_SIZE_RGB  (IMAGE_WIDTH * IMAGE_HEIGHT * 3)

// 内存缓冲区地址（可从 BIOS 或设备树获取）
#define DDR_BASE        0xa0000000UL
#define IMG_SOURCE_RGB  (DDR_BASE + 0x10000000)      // RGB 源图像
#define IMG_GRAY        (DDR_BASE + 0x12000000)      // 灰度中间结果
#define IMG_EDGE        (DDR_BASE + 0x14000000)      // 边缘检测结果
#define IMG_BLUR        (DDR_BASE + 0x16000000)      // 模糊结果

// ============================================
// 状态变量
// ============================================

volatile uint32_t isp_processing = 0;
volatile uint32_t isp_complete = 0;
volatile uint32_t button_pressed = 0;

enum {
    MODE_IDLE = 0,
    MODE_GRAYSCALE,
    MODE_SOBEL_EDGE,
    MODE_GAUSSIAN_BLUR,
    MODE_PIPELINE
};

volatile uint32_t current_mode = MODE_IDLE;

// ============================================
// ISP 中断处理
// ============================================

void isp_interrupt_handler(void) {
    isp_complete = 1;
    isp_processing = 0;
    printf("[ISP] Processing complete\n");
}

// ============================================
// ConfReg 中断处理
// ============================================

void timer_interrupt_handler(void) {
    // 定时器中断，可用于定期处理
    printf("[Timer] Tick\n");
}

void button_interrupt_handler(uint32_t button_state) {
    printf("[Button] State: 0x%x\n", button_state);
    
    // 按钮 1: 灰度化
    if (button_state & 0x1) {
        current_mode = MODE_GRAYSCALE;
        button_pressed = 1;
        printf("[Button 1] Grayscale mode selected\n");
    }
    // 按钮 2: Sobel 边缘
    else if (button_state & 0x2) {
        current_mode = MODE_SOBEL_EDGE;
        button_pressed = 1;
        printf("[Button 2] Sobel edge mode selected\n");
    }
    // 按钮 3: 高斯模糊
    else if (button_state & 0x4) {
        current_mode = MODE_GAUSSIAN_BLUR;
        button_pressed = 1;
        printf("[Button 3] Gaussian blur mode selected\n");
    }
    // 按钮 4: 流水线处理
    else if (button_state & 0x8) {
        current_mode = MODE_PIPELINE;
        button_pressed = 1;
        printf("[Button 4] Pipeline mode selected\n");
    }
}

void HWI0_IntrHandler(void) {
    uint32_t int_state = RegRead(0xbf20f014);
    
    if (int_state & 0x10) {
        timer_interrupt_handler();
    } else if (int_state & 0xf) {
        button_interrupt_handler(int_state & 0xf);
    }
}

// ============================================
// 测试图像生成
// ============================================

/**
 * 生成测试 RGB 图像（渐变彩色矩形）
 */
void generate_test_rgb_image(void) {
    uint8_t *img = (uint8_t *)IMG_SOURCE_RGB;
    
    printf("[Image] Generating test RGB image...\n");
    
    // 上半部分：红色渐变
    for (int i = 0; i < IMAGE_HEIGHT / 2; i++) {
        for (int j = 0; j < IMAGE_WIDTH; j++) {
            int idx = (i * IMAGE_WIDTH + j) * 3;
            img[idx + 0] = (j * 255 / IMAGE_WIDTH);  // R
            img[idx + 1] = 0;                          // G
            img[idx + 2] = 0;                          // B
        }
    }
    
    // 下半部分：蓝色渐变
    for (int i = IMAGE_HEIGHT / 2; i < IMAGE_HEIGHT; i++) {
        for (int j = 0; j < IMAGE_WIDTH; j++) {
            int idx = (i * IMAGE_WIDTH + j) * 3;
            img[idx + 0] = 0;                          // R
            img[idx + 1] = 0;                          // G
            img[idx + 2] = (j * 255 / IMAGE_WIDTH);   // B
        }
    }
    
    printf("[Image] Test image generated at 0x%08x\n", IMG_SOURCE_RGB);
}

/**
 * 加载图像从外部来源（如文件或摄像头）
 * 这里简化为生成测试模式
 */
void load_test_image(void) {
    generate_test_rgb_image();
}

// ============================================
// ISP 处理任务
// ============================================

void process_grayscale_task(void) {
    printf("\n================================================\n");
    printf("Processing: RGB -> Grayscale\n");
    printf("================================================\n");
    
    isp_processing = 1;
    isp_complete = 0;
    
    int ret = isp_grayscale_convert(IMG_SOURCE_RGB, IMG_GRAY, 
                                    IMAGE_WIDTH, IMAGE_HEIGHT, 1);
    
    if (ret == 0) {
        printf("[SUCCESS] Grayscale conversion complete\n");
        printf("[Output] Grayscale image at 0x%08x (%d bytes)\n", 
               IMG_GRAY, IMAGE_SIZE);
    } else {
        printf("[ERROR] Grayscale conversion failed\n");
    }
}

void process_sobel_edge_task(void) {
    printf("\n================================================\n");
    printf("Processing: Grayscale -> Sobel Edge Detection\n");
    printf("================================================\n");
    
    isp_processing = 1;
    isp_complete = 0;
    
    int ret = isp_sobel_edge_detect(IMG_GRAY, IMG_EDGE,
                                    IMAGE_WIDTH, IMAGE_HEIGHT, 
                                    50,  // threshold
                                    1);  // enable_dvi
    
    if (ret == 0) {
        printf("[SUCCESS] Sobel edge detection complete\n");
        printf("[Output] Edge image at 0x%08x\n", IMG_EDGE);
        printf("[TIP] Edges should be visible on DVI display now\n");
    } else {
        printf("[ERROR] Sobel edge detection failed\n");
    }
}

void process_gaussian_blur_task(void) {
    printf("\n================================================\n");
    printf("Processing: Grayscale -> Gaussian Blur\n");
    printf("================================================\n");
    
    isp_processing = 1;
    isp_complete = 0;
    
    int ret = isp_gaussian_blur(IMG_GRAY, IMG_BLUR, 
                                IMAGE_WIDTH, IMAGE_HEIGHT, 1);
    
    if (ret == 0) {
        printf("[SUCCESS] Gaussian blur complete\n");
        printf("[Output] Blurred image at 0x%08x\n", IMG_BLUR);
    } else {
        printf("[ERROR] Gaussian blur failed\n");
    }
}

void process_pipeline_task(void) {
    printf("\n================================================\n");
    printf("Processing: RGB -> Gray -> Sobel -> DVI\n");
    printf("================================================\n");
    
    isp_processing = 1;
    isp_complete = 0;
    
    int ret = isp_pipeline_process(IMG_SOURCE_RGB, IMG_GRAY, IMG_EDGE,
                                   IMAGE_WIDTH, IMAGE_HEIGHT);
    
    if (ret == 0) {
        printf("[SUCCESS] Pipeline processing complete\n");
        printf("[OUTPUT] Edge contours should be shown on DVI\n");
    } else {
        printf("[ERROR] Pipeline processing failed\n");
    }
}

// ============================================
// 主程序
// ============================================

int main(int argc, char** argv) {
    printf("\n");
    printf("====================================\n");
    printf("AXI ISP Core Demonstration\n");
    printf("Image Signal Processing on DVI\n");
    printf("====================================\n\n");
    
    // 初始化 ISP Core
    printf("[Init] Initializing ISP Core...\n");
    isp_init();
    printf("[Init] ISP Core ready at 0x%08x\n", ISP_BASE_ADDR);
    
    // 生成或加载测试图像
    printf("[Init] Loading test image...\n");
    load_test_image();
    
    // 配置硬件中断
    printf("[Init] Setting up interrupts...\n");
    RegWrite(0xbf20f500, 1);  // simu_flag
    RegWrite(0xbf20f004, 0x1f);  // edge (GPIO edge)
    RegWrite(0xbf20f008, 0x1f);  // pol (GPIO polarity)
    RegWrite(0xbf20f00c, 0x1f);  // clr (clear interrupts)
    RegWrite(0xbf20f000, 0x1f);  // en (enable GPIO interrupts)
    RegWrite(0xbf20f104, 50000000);  // timer compare
    RegWrite(0xbf20f108, 1);  // timer enable
    
    printf("[Init] System ready\n\n");
    
    // 主循环
    printf("Available modes (press buttons on board):\n");
    printf("  Button 1: Grayscale conversion\n");
    printf("  Button 2: Sobel edge detection\n");
    printf("  Button 3: Gaussian blur\n");
    printf("  Button 4: Full pipeline (RGB->Gray->Sobel->DVI)\n");
    printf("\nWaiting for button press...\n");
    
    while (1) {
        // 检查是否有按钮被按下
        if (button_pressed) {
            button_pressed = 0;
            
            // 根据当前模式执行相应处理
            switch (current_mode) {
                case MODE_GRAYSCALE:
                    process_grayscale_task();
                    break;
                
                case MODE_SOBEL_EDGE:
                    // 先转灰度（如果还没有）
                    if (!isp_processing) {
                        printf("[PREP] Converting to grayscale first...\n");
                        isp_grayscale_convert(IMG_SOURCE_RGB, IMG_GRAY,
                                            IMAGE_WIDTH, IMAGE_HEIGHT, 0);
                        
                        // 等待灰度化完成
                        isp_wait_complete(5000);
                        printf("[Ready] Grayscale complete, starting Sobel...\n");
                    }
                    process_sobel_edge_task();
                    break;
                
                case MODE_GAUSSIAN_BLUR:
                    if (!isp_processing) {
                        printf("[PREP] Converting to grayscale first...\n");
                        isp_grayscale_convert(IMG_SOURCE_RGB, IMG_GRAY,
                                            IMAGE_WIDTH, IMAGE_HEIGHT, 0);
                        isp_wait_complete(5000);
                        printf("[Ready] Grayscale complete, starting blur...\n");
                    }
                    process_gaussian_blur_task();
                    break;
                
                case MODE_PIPELINE:
                    process_pipeline_task();
                    break;
                
                default:
                    printf("[ERROR] Unknown mode\n");
            }
        }
        
        // 持续检查 ISP 状态
        if (isp_processing) {
            isp_status_t status = isp_get_status();
            
            if (status.is_complete) {
                printf("[Status] ISP processing complete\n");
                isp_processing = 0;
            }
            
            if (status.has_error) {
                printf("[ERROR] ISP error detected\n");
                isp_processing = 0;
            }
        }
    }
    
    return 0;
}

