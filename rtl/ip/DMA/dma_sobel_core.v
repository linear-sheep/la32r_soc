module dma_sobel_core (
    input  wire        aclk,
    input  wire        aresetn,

    // 控制与配置信号
    input  wire        start,
    output reg         done,
    input  wire [31:0] src_addr,
    input  wire [31:0] dst_addr,
    input  wire [15:0] width,
    input  wire [15:0] height,

    // AXI Master Read 接口
    output wire [3:0]  m_arid,
    output wire [31:0] m_araddr,
    output wire [7:0]  m_arlen,
    output wire [2:0]  m_arsize,
    output wire [1:0]  m_arburst,
    output wire        m_arlock,
    output wire [3:0]  m_arcache,
    output wire [2:0]  m_arprot,
    output wire        m_arvalid,
    input  wire        m_arready,

    input  wire [3:0]  m_rid,
    input  wire [31:0] m_rdata,
    input  wire [1:0]  m_rresp,
    input  wire        m_rlast,
    input  wire        m_rvalid,
    output wire        m_rready,

    // AXI Master Write 接口
    output wire [3:0]  m_awid,
    output wire [31:0] m_awaddr,
    output wire [7:0]  m_awlen,
    output wire [2:0]  m_awsize,
    output wire [1:0]  m_awburst,
    output wire        m_awlock,
    output wire [3:0]  m_awcache,
    output wire [2:0]  m_awprot,
    output wire        m_awvalid,
    input  wire        m_awready,

    output wire [3:0]  m_wid,
    output wire [31:0] m_wdata,
    output wire [3:0]  m_wstrb,
    output wire        m_wlast,
    output wire        m_wvalid,
    input  wire        m_wready,

    input  wire [3:0]  m_bid,
    input  wire [1:0]  m_bresp,
    input  wire        m_bvalid,
    output wire        m_bready
);

    // 状态机参数
    localparam ST_IDLE    = 4'd0;
    localparam ST_RD_REQ  = 4'd1;
    localparam ST_RD_WAIT = 4'd2;
    localparam ST_CALC    = 4'd3;
    localparam ST_AW_REQ  = 4'd4;
    localparam ST_W_REQ   = 4'd5;
    localparam ST_WR_WAIT = 4'd6;
    localparam ST_DONE    = 4'd7;

    reg [3:0]  state;
    reg [15:0] x_cnt;
    reg [15:0] y_cnt;
    reg [3:0]  pixel_idx;
    reg [31:0] fetch_addr;
    
    // 3x3 像素窗口，使用标准的寄存器数组
    reg [7:0]  window [0:8];

    // ==========================================
    // 状态机与控制逻辑
    // ==========================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state     <= ST_IDLE;
            x_cnt     <= 16'd0;
            y_cnt     <= 16'd0;
            pixel_idx <= 4'd0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0; // 默认拉低
            
            case (state)
                ST_IDLE: begin
                    if (start) begin
                        state     <= ST_RD_REQ;
                        x_cnt     <= 16'd0;
                        y_cnt     <= 16'd0;
                        pixel_idx <= 4'd0;
                    end
                end
                
                ST_RD_REQ: begin
                    if (m_arready) state <= ST_RD_WAIT;
                end

                ST_RD_WAIT: begin
                    if (m_rvalid && m_rready) begin
                        // 字节对齐抽取：根据地址低两位决定偏移
                        window[pixel_idx] <= m_rdata >> (fetch_addr[1:0] * 8);
                        
                        if (pixel_idx == 4'd8) begin
                            state <= ST_CALC;
                        end else begin
                            pixel_idx <= pixel_idx + 4'd1;
                            state <= ST_RD_REQ;
                        end
                    end
                end

                ST_CALC: begin
                    // 运算在组合逻辑中完成，此处直接跳转至写请求
                    state <= ST_AW_REQ;
                end

                ST_AW_REQ: begin
                    if (m_awready) state <= ST_W_REQ;
                end

                ST_W_REQ: begin
                    if (m_wready) state <= ST_WR_WAIT;
                end

                ST_WR_WAIT: begin
                    if (m_bvalid && m_bready) begin
                        pixel_idx <= 4'd0;
                        if (x_cnt == width - 1'b1) begin
                            x_cnt <= 16'd0;
                            if (y_cnt == height - 1'b1) begin
                                state <= ST_DONE;
                            end else begin
                                y_cnt <= y_cnt + 16'd1;
                                state <= ST_RD_REQ;
                            end
                        end else begin
                            x_cnt <= x_cnt + 16'd1;
                            state <= ST_RD_REQ;
                        end
                    end
                end

                ST_DONE: begin
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    // ==========================================
    // 地址生成逻辑
    // ==========================================
    integer dx, dy;
    always @(*) begin
        // 计算 3x3 窗口的偏移量
        dx = (pixel_idx % 3) - 1;
        dy = (pixel_idx / 3) - 1;

        // 边界保护：若越界则取当前中心像素坐标替代
        if ($signed({1'b0, x_cnt}) + dx < 0 ||
            $signed({1'b0, x_cnt}) + dx >= width ||
            $signed({1'b0, y_cnt}) + dy < 0 ||
            $signed({1'b0, y_cnt}) + dy >= height) begin
            
            fetch_addr = src_addr + y_cnt * width + x_cnt;
        end else begin
            fetch_addr = src_addr + (y_cnt + dy) * width + (x_cnt + dx);
        end
    end

    // ==========================================
    // Sobel 算子与灰度化组合逻辑
    // ==========================================
    
    // Verilog 2001 函数定义，位于 module 内部且不在 always 块中
    function [7:0] get_gray;
        input [7:0] rgb;
        begin
            // 把 RGB332 拆成 R(3) G(3) B(2) 转换到近似灰度
            get_gray = ({rgb[7:5], 5'b0} >> 2) + ({rgb[4:2], 5'b0} >> 1) + ({rgb[1:0], 6'b0} >> 2);
        end
    endfunction

    // 独立展开提取 9 个像素的灰度值，避免 Vivado 对线网数组的兼容性报错
    wire [7:0] g0 = get_gray(window[0]);
    wire [7:0] g1 = get_gray(window[1]);
    wire [7:0] g2 = get_gray(window[2]);
    wire [7:0] g3 = get_gray(window[3]);
    wire [7:0] g4 = get_gray(window[4]);
    wire [7:0] g5 = get_gray(window[5]);
    wire [7:0] g6 = get_gray(window[6]);
    wire [7:0] g7 = get_gray(window[7]);
    wire [7:0] g8 = get_gray(window[8]);

    // Gx 梯度 (横向边缘)
    wire [10:0] gx_p = g2 + (g5 << 1) + g8;
    wire [10:0] gx_n = g0 + (g3 << 1) + g6;
    wire [11:0] gx_abs = (gx_p > gx_n) ? (gx_p - gx_n) : (gx_n - gx_p);

    // Gy 梯度 (纵向边缘)
    wire [10:0] gy_p = g6 + (g7 << 1) + g8;
    wire [10:0] gy_n = g0 + (g1 << 1) + g2;
    wire [11:0] gy_abs = (gy_p > gy_n) ? (gy_p - gy_n) : (gy_n - gy_p);

    // 梯度幅值近似
    wire [11:0] g_total = gx_abs + gy_abs;
    
    // 结果判定：边缘一圈固定输出0；其余由阈值判定
    wire [7:0] res_pixel;
    assign res_pixel = (x_cnt == 0 || x_cnt == width - 1'b1 || y_cnt == 0 || y_cnt == height - 1'b1) ? 
                        8'd0 : 
                        (g_total > 12'd100) ? 8'b111_111_11 : 8'd0;

    // ==========================================
    // AXI 读写接口赋值
    // ==========================================
    
    // AXI 读请求
    assign m_arid    = 4'd0;
    assign m_araddr  = {fetch_addr[31:2], 2'b00}; // 4字节对齐
    assign m_arlen   = 8'd0;
    assign m_arsize  = 3'b000;
    assign m_arburst = 2'b01;
    assign m_arlock  = 1'b0;
    assign m_arcache = 4'b0000;
    assign m_arprot  = 3'b000;
    assign m_arvalid = (state == ST_RD_REQ);
    assign m_rready  = (state == ST_RD_WAIT);

    // AXI 写请求地址准备
    wire [31:0] aw_full_addr = dst_addr + y_cnt * width + x_cnt;
    
    assign m_awid    = 4'd0;
    assign m_awaddr  = {aw_full_addr[31:2], 2'b00};
    assign m_awlen   = 8'd0;
    assign m_awsize  = 3'b000;
    assign m_awburst = 2'b01;
    assign m_awlock  = 1'b0;
    assign m_awcache = 4'b0000;
    assign m_awprot  = 3'b000;
    assign m_awvalid = (state == ST_AW_REQ);

    // AXI 写数据准备
    wire [1:0] w_offset = aw_full_addr[1:0];
    assign m_wid    = 4'd0;
    assign m_wdata  = {4{res_pixel}};        // 将单字节结果复制到 4 个字节通道
    assign m_wstrb  = (4'b0001 << w_offset); // 选通对应字节
    assign m_wlast  = 1'b1;
    assign m_wvalid = (state == ST_W_REQ);
    
    assign m_bready = (state == ST_WR_WAIT);

endmodule