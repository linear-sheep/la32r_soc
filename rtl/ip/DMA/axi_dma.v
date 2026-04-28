module axi_special_dma (
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4 Slave: DMA config registers (CPU-visible)
    input  wire [3:0]  s_awid,
    input  wire [31:0] s_awaddr,
    input  wire [7:0]  s_awlen,
    input  wire [2:0]  s_awsize,
    input  wire [1:0]  s_awburst,
    input  wire [1:0]  s_awlock,
    input  wire [3:0]  s_awcache,
    input  wire [2:0]  s_awprot,
    input  wire        s_awvalid,
    output wire        s_awready,
    input  wire [3:0]  s_wid,
    input  wire [31:0] s_wdata,
    input  wire [3:0]  s_wstrb,
    input  wire        s_wlast,
    input  wire        s_wvalid,
    output wire        s_wready,
    output wire [3:0]  s_bid,
    output wire [1:0]  s_bresp,
    output wire        s_bvalid,
    input  wire        s_bready,
    input  wire [3:0]  s_arid,
    input  wire [31:0] s_araddr,
    input  wire [7:0]  s_arlen,
    input  wire [2:0]  s_arsize,
    input  wire [1:0]  s_arburst,
    input  wire [1:0]  s_arlock,
    input  wire [3:0]  s_arcache,
    input  wire [2:0]  s_arprot,
    input  wire        s_arvalid,
    output wire        s_arready,
    output wire [3:0]  s_rid,
    output wire [31:0] s_rdata,
    output wire [1:0]  s_rresp,
    output wire        s_rlast,
    output wire        s_rvalid,
    input  wire        s_rready,

    // AXI4 Master: shared DMA read/write channel to crossbar
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
    output wire        m_bready,

    // FB Config Registers 出口 (输出给 SOC 或者 DVI 控制器使用)
    output wire [31:0] fb_base_cfg,
    output wire        fb_en_cfg,

    // DVI 同步信号接口 (用于送入 fb_core 抓取数据)
    input  wire        v_fb_valid,
    input  wire        v_frame_start,
    output wire [31:0] v_fb_pixel
);

    // ==========================================
    // 1. AXI Slave 配置寄存器逻辑
    // ==========================================
    reg [31:0] reg_src_addr;
    reg [31:0] reg_dst_addr;
    reg [31:0] reg_ctrl;
    reg [31:0] reg_dim;
    reg [31:0] reg_fb_base;
    reg [31:0] reg_fb_ctrl;

    assign fb_base_cfg = reg_fb_base;
    assign fb_en_cfg   = reg_fb_ctrl[0];

    reg        s_awready_reg;
    reg        s_wready_reg;
    reg        s_bvalid_reg;
    reg        s_arready_reg;
    reg        s_rvalid_reg;
    reg [31:0] s_rdata_reg;
    reg [31:0] capture_awaddr;
    reg [3:0]  capture_awid;
    reg [3:0]  capture_arid;
    reg [31:0] capture_wdata;
    reg        aw_en;
    reg        w_en;

    assign s_awready = s_awready_reg;
    assign s_wready  = s_wready_reg;
    assign s_bvalid  = s_bvalid_reg;
    assign s_arready = s_arready_reg;
    assign s_rvalid  = s_rvalid_reg;
    assign s_rdata   = s_rdata_reg;
    assign s_bresp   = 2'b00;
    assign s_rresp   = 2'b00;
    assign s_rlast   = s_rvalid_reg;
    assign s_rid     = capture_arid;
    assign s_bid     = capture_awid;

    reg start_pulse;
    wire dma_done; // 来自 sobel_core

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            reg_src_addr   <= 32'h0;
            reg_dst_addr   <= 32'h0;
            reg_ctrl       <= 32'h0;
            reg_dim        <= 32'h0;
            reg_fb_base    <= 32'h1c40_0000;
            reg_fb_ctrl    <= 32'h0;
            s_awready_reg  <= 1'b0;
            s_wready_reg   <= 1'b0;
            s_bvalid_reg   <= 1'b0;
            s_arready_reg  <= 1'b0;
            s_rvalid_reg   <= 1'b0;
            capture_awaddr <= 32'h0;
            capture_awid   <= 4'h0;
            capture_arid   <= 4'h0;
            capture_wdata  <= 32'h0;
            aw_en          <= 1'b0;
            w_en           <= 1'b0;
            start_pulse    <= 1'b0;
        end else begin
            start_pulse <= 1'b0;
            if (dma_done) begin
                reg_ctrl[0] <= 1'b1;
            end

            // Write channel
            if (s_awvalid && !s_awready_reg && !s_bvalid_reg && !aw_en) begin
                s_awready_reg  <= 1'b1;
                capture_awaddr <= s_awaddr;
                capture_awid   <= s_awid;
                aw_en          <= 1'b1;
            end else begin
                s_awready_reg <= 1'b0;
            end

            if (s_wvalid && !s_wready_reg && !s_bvalid_reg && !w_en) begin
                s_wready_reg <= 1'b1;
                capture_wdata <= s_wdata;
                w_en <= 1'b1;
            end else begin
                s_wready_reg <= 1'b0;
            end

            if (aw_en && w_en) begin
                s_bvalid_reg <= 1'b1;
                aw_en <= 1'b0;
                w_en  <= 1'b0;
                case (capture_awaddr[7:0])
                    8'h00: reg_src_addr <= capture_wdata;
                    8'h04: reg_dst_addr <= capture_wdata;
                    8'h08: begin
                        if (capture_wdata[0]) begin
                            start_pulse  <= 1'b1;
                            reg_ctrl[0]  <= 1'b0;
                        end
                    end
                    8'h0C: reg_dim <= capture_wdata;
                    8'h10: reg_fb_base <= capture_wdata;
                    8'h14: reg_fb_ctrl <= capture_wdata;
                    default: begin end
                endcase
            end else if (s_bready && s_bvalid_reg) begin
                s_bvalid_reg <= 1'b0;
            end

            // Read channel
            if (s_arvalid && !s_arready_reg && !s_rvalid_reg) begin
                s_arready_reg <= 1'b1;
                capture_arid  <= s_arid;
                case (s_araddr[7:0])
                    8'h00: s_rdata_reg <= reg_src_addr;
                    8'h04: s_rdata_reg <= reg_dst_addr;
                    8'h08: s_rdata_reg <= reg_ctrl;
                    8'h0C: s_rdata_reg <= reg_dim;
                    8'h10: s_rdata_reg <= reg_fb_base;
                    8'h14: s_rdata_reg <= reg_fb_ctrl;
                    default: s_rdata_reg <= 32'h0;
                endcase
            end else begin
                s_arready_reg <= 1'b0;
            end

            if (s_arready_reg && s_arvalid) begin
                s_rvalid_reg <= 1'b1;
            end else if (s_rvalid_reg && s_rready) begin
                s_rvalid_reg <= 1'b0;
            end
        end
    end

    // ==========================================
    // 2. 内部核心连线
    // ==========================================
    
    // Sobel 接口信号
    wire [3:0]  sobel_arid;
    wire [31:0] sobel_araddr;
    wire [7:0]  sobel_arlen;
    wire [2:0]  sobel_arsize;
    wire [1:0]  sobel_arburst;
    wire        sobel_arlock;
    wire [3:0]  sobel_arcache;
    wire [2:0]  sobel_arprot;
    wire        sobel_arvalid;
    wire        sobel_arready;
    wire        sobel_rvalid;
    wire        sobel_rready;

    dma_sobel_core u_sobel_core (
        .aclk       (aclk),
        .aresetn    (aresetn),
        .start      (start_pulse),
        .done       (dma_done),
        .src_addr   (reg_src_addr),
        .dst_addr   (reg_dst_addr),
        .width      (reg_dim[15:0]),
        .height     (reg_dim[31:16]),

        // Read channel (To Arbiter)
        .m_arid     (sobel_arid),
        .m_araddr   (sobel_araddr),
        .m_arlen    (sobel_arlen),
        .m_arsize   (sobel_arsize),
        .m_arburst  (sobel_arburst),
        .m_arlock   (sobel_arlock),
        .m_arcache  (sobel_arcache),
        .m_arprot   (sobel_arprot),
        .m_arvalid  (sobel_arvalid),
        .m_arready  (sobel_arready),
        .m_rid      (m_rid),
        .m_rdata    (m_rdata),
        .m_rresp    (m_rresp),
        .m_rlast    (m_rlast),
        .m_rvalid   (sobel_rvalid),
        .m_rready   (sobel_rready),

        // Write channel (直通外部 Master)
        .m_awid     (m_awid),
        .m_awaddr   (m_awaddr),
        .m_awlen    (m_awlen),
        .m_awsize   (m_awsize),
        .m_awburst  (m_awburst),
        .m_awlock   (m_awlock),
        .m_awcache  (m_awcache),
        .m_awprot   (m_awprot),
        .m_awvalid  (m_awvalid),
        .m_awready  (m_awready),
        .m_wid      (m_wid),
        .m_wdata    (m_wdata),
        .m_wstrb    (m_wstrb),
        .m_wlast    (m_wlast),
        .m_wvalid   (m_wvalid),
        .m_wready   (m_wready),
        .m_bid      (m_bid),
        .m_bresp    (m_bresp),
        .m_bvalid   (m_bvalid),
        .m_bready   (m_bready)
    );

    // FB 接口信号
    wire [3:0]  v_arid;
    wire [31:0] v_araddr;
    wire [7:0]  v_arlen;
    wire [2:0]  v_arsize;
    wire [1:0]  v_arburst;
    wire        v_arlock;
    wire [3:0]  v_arcache;
    wire [2:0]  v_arprot;
    wire        v_arvalid;
    wire        v_arready;
    wire        v_rvalid;
    wire        v_rready;

    dma_fb_core u_fb_core (
        .aclk       (aclk),
        .aresetn    (aresetn),
        .fb_base    (reg_fb_base),
        .fb_en      (reg_fb_ctrl[0]),
        
        // Read channel (To Arbiter)
        .m_arvalid  (v_arvalid),
        .m_arready  (v_arready),
        .m_araddr   (v_araddr),
        .m_arid     (v_arid),
        .m_arlen    (v_arlen),
        .m_arsize   (v_arsize),
        .m_arburst  (v_arburst),
        .m_arlock   (v_arlock),
        .m_arcache  (v_arcache),
        .m_arprot   (v_arprot),
        .m_rvalid   (v_rvalid),
        .m_rready   (v_rready),
        .m_rdata    (m_rdata),
        .m_rid      (m_rid),
        .m_rresp    (m_rresp),
        .m_rlast    (m_rlast),

        // Video Sync (来自 DVI 侧)
        .fb_valid   (v_fb_valid),
        .frame_start(v_frame_start),
        .fb_pixel   (v_fb_pixel)
    );

    // ==========================================
    // 3. AXI 读通道仲裁器 (DVI > Sobel)
    // ==========================================
    localparam RD_IDLE  = 2'd0;
    localparam RD_SOBEL = 2'd1;
    localparam RD_DVI   = 2'd2;

    reg [1:0] rd_owner;
    wire rd_done = m_rvalid && m_rready && m_rlast;

    wire select_dvi_idle   = v_arvalid;
    wire select_sobel_idle = !v_arvalid && sobel_arvalid;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_owner <= RD_IDLE;
        end else begin
            case (rd_owner)
                RD_IDLE: begin
                    if (select_dvi_idle && m_arready) begin
                        rd_owner <= RD_DVI;
                    end else if (select_sobel_idle && m_arready) begin
                        rd_owner <= RD_SOBEL;
                    end
                end
                RD_SOBEL: if (rd_done) rd_owner <= RD_IDLE;
                RD_DVI:   if (rd_done) rd_owner <= RD_IDLE;
                default: rd_owner <= RD_IDLE;
            endcase
        end
    end

    assign m_arid    = (rd_owner == RD_IDLE) ? (select_dvi_idle ? v_arid    : sobel_arid)    : 4'd0;
    assign m_araddr  = (rd_owner == RD_IDLE) ? (select_dvi_idle ? v_araddr  : sobel_araddr)  : 32'd0;
    assign m_arlen   = (rd_owner == RD_IDLE) ? (select_dvi_idle ? v_arlen   : sobel_arlen)   : 8'd0;
    assign m_arsize  = (rd_owner == RD_IDLE) ? (select_dvi_idle ? v_arsize  : sobel_arsize)  : 3'd0;
    assign m_arburst = (rd_owner == RD_IDLE) ? (select_dvi_idle ? v_arburst : sobel_arburst) : 2'd0;
    assign m_arlock  = (rd_owner == RD_IDLE) ? (select_dvi_idle ? v_arlock  : sobel_arlock)  : 1'b0;
    assign m_arcache = (rd_owner == RD_IDLE) ? (select_dvi_idle ? v_arcache : sobel_arcache) : 4'd0;
    assign m_arprot  = (rd_owner == RD_IDLE) ? (select_dvi_idle ? v_arprot  : sobel_arprot)  : 3'd0;
    assign m_arvalid = (rd_owner == RD_IDLE) ? (select_dvi_idle || select_sobel_idle)        : 1'b0;
    
    assign v_arready     = (rd_owner == RD_IDLE && select_dvi_idle) ? m_arready : 1'b0;
    assign sobel_arready = (rd_owner == RD_IDLE && select_sobel_idle) ? m_arready : 1'b0;

    assign v_rvalid     = (rd_owner == RD_DVI) ? m_rvalid : 1'b0;
    assign sobel_rvalid = (rd_owner == RD_SOBEL) ? m_rvalid : 1'b0;
    
    assign m_rready = (rd_owner == RD_DVI) ? v_rready :
                      (rd_owner == RD_SOBEL) ? sobel_rready : 1'b1;

endmodule