module axi_arb_2to1 (
    input  wire        aclk,
    input  wire        aresetn,

    // Port 0: CPU Data (High Priority)
    input  wire [3:0]  s0_awid,
    input  wire [31:0] s0_awaddr,
    input  wire [7:0]  s0_awlen,
    input  wire [2:0]  s0_awsize,
    input  wire [1:0]  s0_awburst,
    input  wire [1:0]  s0_awlock,
    input  wire [3:0]  s0_awcache,
    input  wire [2:0]  s0_awprot,
    input  wire        s0_awvalid,
    output wire        s0_awready,
    input  wire [3:0]  s0_wid,
    input  wire [31:0] s0_wdata,
    input  wire [3:0]  s0_wstrb,
    input  wire        s0_wlast,
    input  wire        s0_wvalid,
    output wire        s0_wready,
    output wire [3:0]  s0_bid,
    output wire [1:0]  s0_bresp,
    output wire        s0_bvalid,
    input  wire        s0_bready,
    input  wire [3:0]  s0_arid,
    input  wire [31:0] s0_araddr,
    input  wire [7:0]  s0_arlen,
    input  wire [2:0]  s0_arsize,
    input  wire [1:0]  s0_arburst,
    input  wire [1:0]  s0_arlock,
    input  wire [3:0]  s0_arcache,
    input  wire [2:0]  s0_arprot,
    input  wire        s0_arvalid,
    output wire        s0_arready,
    output wire [3:0]  s0_rid,
    output wire [31:0] s0_rdata,
    output wire [1:0]  s0_rresp,
    output wire        s0_rlast,
    output wire        s0_rvalid,
    input  wire        s0_rready,

    // Port 1: Sobel DMA (Low Priority)
    input  wire [3:0]  s1_awid,
    input  wire [31:0] s1_awaddr,
    input  wire [7:0]  s1_awlen,
    input  wire [2:0]  s1_awsize,
    input  wire [1:0]  s1_awburst,
    input  wire [1:0]  s1_awlock,
    input  wire [3:0]  s1_awcache,
    input  wire [2:0]  s1_awprot,
    input  wire        s1_awvalid,
    output wire        s1_awready,
    input  wire [3:0]  s1_wid,
    input  wire [31:0] s1_wdata,
    input  wire [3:0]  s1_wstrb,
    input  wire        s1_wlast,
    input  wire        s1_wvalid,
    output wire        s1_wready,
    output wire [3:0]  s1_bid,
    output wire [1:0]  s1_bresp,
    output wire        s1_bvalid,
    input  wire        s1_bready,
    input  wire [3:0]  s1_arid,
    input  wire [31:0] s1_araddr,
    input  wire [7:0]  s1_arlen,
    input  wire [2:0]  s1_arsize,
    input  wire [1:0]  s1_arburst,
    input  wire [1:0]  s1_arlock,
    input  wire [3:0]  s1_arcache,
    input  wire [2:0]  s1_arprot,
    input  wire        s1_arvalid,
    output wire        s1_arready,
    output wire [3:0]  s1_rid,
    output wire [31:0] s1_rdata,
    output wire [1:0]  s1_rresp,
    output wire        s1_rlast,
    output wire        s1_rvalid,
    input  wire        s1_rready,

    // Master Port: To Crossbar
    output wire [3:0]  m_awid,
    output wire [31:0] m_awaddr,
    output wire [7:0]  m_awlen,
    output wire [2:0]  m_awsize,
    output wire [1:0]  m_awburst,
    output wire [1:0]  m_awlock,
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
    output wire [3:0]  m_arid,
    output wire [31:0] m_araddr,
    output wire [7:0]  m_arlen,
    output wire [2:0]  m_arsize,
    output wire [1:0]  m_arburst,
    output wire [1:0]  m_arlock,
    output wire [3:0]  m_arcache,
    output wire [2:0]  m_arprot,
    output wire        m_arvalid,
    input  wire        m_arready,
    input  wire [3:0]  m_rid,
    input  wire [31:0] m_rdata,
    input  wire [1:0]  m_rresp,
    input  wire        m_rlast,
    input  wire        m_rvalid,
    output wire        m_rready
);
    // 简化的静态优先级仲裁：如果 S0 有请求且处于未完成状态，则锁死 M给S0；否则给S1
    reg s0_active_aw;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) s0_active_aw <= 1'b0;
        else if (s0_awvalid && m_awready) s0_active_aw <= 1'b1;
        else if (s0_bvalid && s0_bready) s0_active_aw <= 1'b0;
    end

    reg s0_active_ar;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) s0_active_ar <= 1'b0;
        else if (s0_arvalid && m_arready) s0_active_ar <= 1'b1;
        else if (s0_rvalid && s0_rready && s0_rlast) s0_active_ar <= 1'b0;
    end

    wire sel_s0_w = s0_awvalid | s0_active_aw;
    wire sel_s0_r = s0_arvalid | s0_active_ar;

    // Write Address
    assign m_awid    = sel_s0_w ? s0_awid    : s1_awid;
    assign m_awaddr  = sel_s0_w ? s0_awaddr  : s1_awaddr;
    assign m_awlen   = sel_s0_w ? s0_awlen   : s1_awlen;
    assign m_awsize  = sel_s0_w ? s0_awsize  : s1_awsize;
    assign m_awburst = sel_s0_w ? s0_awburst : s1_awburst;
    assign m_awlock  = sel_s0_w ? s0_awlock  : s1_awlock;
    assign m_awcache = sel_s0_w ? s0_awcache : s1_awcache;
    assign m_awprot  = sel_s0_w ? s0_awprot  : s1_awprot;
    assign m_awvalid = sel_s0_w ? s0_awvalid : s1_awvalid;
    assign s0_awready= sel_s0_w ? m_awready  : 1'b0;
    assign s1_awready= !sel_s0_w? m_awready  : 1'b0;

    // Write Data
    assign m_wid     = sel_s0_w ? s0_wid     : s1_wid;
    assign m_wdata   = sel_s0_w ? s0_wdata   : s1_wdata;
    assign m_wstrb   = sel_s0_w ? s0_wstrb   : s1_wstrb;
    assign m_wlast   = sel_s0_w ? s0_wlast   : s1_wlast;
    assign m_wvalid  = sel_s0_w ? s0_wvalid  : s1_wvalid;
    assign s0_wready = sel_s0_w ? m_wready   : 1'b0;
    assign s1_wready = !sel_s0_w? m_wready   : 1'b0;

    // Write Response
    assign s0_bid    = m_bid;
    assign s0_bresp  = m_bresp;
    assign s0_bvalid = sel_s0_w ? m_bvalid   : 1'b0;
    assign s1_bid    = m_bid;
    assign s1_bresp  = m_bresp;
    assign s1_bvalid = !sel_s0_w? m_bvalid   : 1'b0;
    assign m_bready  = sel_s0_w ? s0_bready  : s1_bready;

    // Read Address
    assign m_arid    = sel_s0_r ? s0_arid    : s1_arid;
    assign m_araddr  = sel_s0_r ? s0_araddr  : s1_araddr;
    assign m_arlen   = sel_s0_r ? s0_arlen   : s1_arlen;
    assign m_arsize  = sel_s0_r ? s0_arsize  : s1_arsize;
    assign m_arburst = sel_s0_r ? s0_arburst : s1_arburst;
    assign m_arlock  = sel_s0_r ? s0_arlock  : s1_arlock;
    assign m_arcache = sel_s0_r ? s0_arcache : s1_arcache;
    assign m_arprot  = sel_s0_r ? s0_arprot  : s1_arprot;
    assign m_arvalid = sel_s0_r ? s0_arvalid : s1_arvalid;
    assign s0_arready= sel_s0_r ? m_arready  : 1'b0;
    assign s1_arready= !sel_s0_r? m_arready  : 1'b0;

    // Read Data
    assign s0_rid    = m_rid;
    assign s0_rdata  = m_rdata;
    assign s0_rresp  = m_rresp;
    assign s0_rlast  = m_rlast;
    assign s0_rvalid = sel_s0_r ? m_rvalid   : 1'b0;
    assign s1_rid    = m_rid;
    assign s1_rdata  = m_rdata;
    assign s1_rresp  = m_rresp;
    assign s1_rlast  = m_rlast;
    assign s1_rvalid = !sel_s0_r? m_rvalid   : 1'b0;
    assign m_rready  = sel_s0_r ? s0_rready  : s1_rready;

endmodule