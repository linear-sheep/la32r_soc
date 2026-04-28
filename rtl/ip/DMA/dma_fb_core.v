module dma_fb_core #(
    parameter [31:0] FB_BASE_DEFAULT = 32'h1c40_0000
)(
    input  wire        aclk,
    input  wire        aresetn,

    // 控制信号 (来自 axi_dma)
    input  wire [31:0] fb_base,       
    input  wire        fb_en,         

    // AXI Master Read 接口 (连向仲裁器)
    output wire        m_arvalid,
    input  wire        m_arready,
    output wire [31:0] m_araddr,
    output wire [3:0]  m_arid,
    output wire [7:0]  m_arlen,
    output wire [2:0]  m_arsize,
    output wire [1:0]  m_arburst,
    output wire        m_arlock,
    output wire [3:0]  m_arcache,
    output wire [2:0]  m_arprot,

    input  wire        m_rvalid,
    output wire        m_rready,
    input  wire [31:0] m_rdata,
    input  wire [3:0]  m_rid,
    input  wire [1:0]  m_rresp,
    input  wire        m_rlast,

    // 视频同步接口 (来自/去向 axi_dvi)
    input  wire        fb_valid,      
    input  wire        frame_start,   // vsync
    output wire [31:0] fb_pixel       
);

    // AXI Constants
    assign m_arid    = 4'd0;
    assign m_arsize  = 3'b010;
    assign m_arburst = 2'b01;  
    assign m_arlock  = 1'b0;
    assign m_arcache = 4'b0;
    assign m_arprot  = 3'b0;

    reg [31:0] fetch_addr;
    reg vsync_d;
    always @(posedge aclk) begin
        if(!aresetn) vsync_d <= 1'b0; 
        else vsync_d <= frame_start;
    end
    wire vsync_rise = frame_start & ~vsync_d;

    (* ram_style = "block" *) reg [31:0] fifo [0:1023];
    reg [9:0]  wr_ptr;
    reg [9:0]  rd_ptr;
    reg [10:0] count;

    localparam [1:0] ST_IDLE = 2'd0, ST_REQ = 2'd1, ST_READ = 2'd2;
    reg [1:0] state;
    wire fb_req_active = fb_en;

    assign m_arvalid = (state == ST_REQ);
    assign m_araddr  = fetch_addr;
    assign m_arlen   = 8'd127;
    assign m_rready  = (state == ST_READ); 

    always @(posedge aclk) begin
        if (!aresetn) begin
            state <= ST_IDLE;
            fetch_addr <= FB_BASE_DEFAULT;
        end else begin
            if (vsync_rise) begin
                state <= ST_IDLE;
                fetch_addr <= fb_en ? fb_base : FB_BASE_DEFAULT;
            end else begin
                case (state)
                    ST_IDLE: begin
                        if (fb_req_active && (count <= (11'd1024 - 11'd128))) begin
                            state <= ST_REQ;
                        end
                    end
                    ST_REQ: begin
                        if (m_arready) state <= ST_READ;
                    end
                    ST_READ: begin
                        if (m_rvalid && m_rready && m_rlast) begin
                            fetch_addr <= fetch_addr + 128 * 4;
                            state <= ST_IDLE;
                        end
                    end
                endcase
            end
        end
    end

    reg [1:0] pixel_mux;
    always @(posedge aclk) begin
        if (!aresetn || vsync_rise) begin
            pixel_mux <= 2'b00;
        end else if (fb_valid) begin
            pixel_mux <= pixel_mux + 2'b01;
        end
    end

    wire pop  = fb_valid && (pixel_mux == 2'b00);
    wire push = (state == ST_READ) && m_rvalid && m_rready;

    always @(posedge aclk) begin
        if (!aresetn || vsync_rise) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end else begin
            if (push && pop) begin
                fifo[wr_ptr] <= m_rdata;
                wr_ptr <= wr_ptr + 1;
                rd_ptr <= rd_ptr + 1;
            end else if (push) begin
                fifo[wr_ptr] <= m_rdata;
                wr_ptr <= wr_ptr + 1;
                count  <= count + 1;
            end else if (pop) begin
                rd_ptr <= rd_ptr + 1;
                if (count > 0) count <= count - 1;
            end
        end
    end

    reg [31:0] raw_data;
    reg [1:0]  pixel_mux_d; 
    reg        pop_d;

    always @(posedge aclk) begin
        if (!aresetn) begin
            raw_data    <= 32'd0;
            pop_d       <= 1'b0;
            pixel_mux_d <= 2'b00;
        end else begin
            pop_d       <= fb_valid;
            pixel_mux_d <= pixel_mux;
            if (pop) raw_data <= fifo[rd_ptr];
        end
    end

    wire [7:0] px8 = (pixel_mux_d == 2'b00) ? raw_data[7:0] :
                     (pixel_mux_d == 2'b01) ? raw_data[15:8] :
                     (pixel_mux_d == 2'b10) ? raw_data[23:16] : raw_data[31:24];

    assign fb_pixel = pop_d ? {8'd0, px8[7:5], 5'd0, px8[4:2], 5'd0, px8[1:0], 6'd0} : 32'd0;

endmodule