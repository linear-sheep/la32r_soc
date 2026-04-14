module axi_read_mux_2to1 (
    input  wire        aclk,
    input  wire        aresetn,

    // Port 0: DMA_M (低优先级)
    input  wire [3:0]  s0_arid,
    input  wire [31:0] s0_araddr,
    input  wire [7:0]  s0_arlen,
    input  wire [2:0]  s0_arsize,
    input  wire [1:0]  s0_arburst,
    input  wire        s0_arlock,
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

    // Port 1: DVI Extfb Reader (高优先级：实时视频流需要优先满足)
    input  wire [3:0]  s1_arid,
    input  wire [31:0] s1_araddr,
    input  wire [7:0]  s1_arlen,
    input  wire [2:0]  s1_arsize,
    input  wire [1:0]  s1_arburst,
    input  wire        s1_arlock,
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

    // Master Port: 连接到 AxiCrossbar 的 axiIn_1
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
    output wire        m_rready
);

    localparam IDLE = 2'd0, S0_READ = 2'd1, S1_READ = 2'd2;
    reg [1:0] state, next_state;

    always @(posedge aclk) begin
        if (!aresetn) state <= IDLE;
        else state <= next_state;
    end

    wire r_done = m_rvalid && m_rready && m_rlast;

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (s1_arvalid) next_state = S1_READ;       // DVI 优先
                else if (s0_arvalid) next_state = S0_READ;  // DMA 其次
            end
            S0_READ: if (r_done) next_state = IDLE;         // 一次猝发完成后释放总线
            S1_READ: if (r_done) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Mux 地址与控制信号 (AR Channel)
    assign m_arid    = (state == S1_READ) ? s1_arid    : s0_arid;
    assign m_araddr  = (state == S1_READ) ? s1_araddr  : s0_araddr;
    assign m_arlen   = (state == S1_READ) ? s1_arlen   : s0_arlen;
    assign m_arsize  = (state == S1_READ) ? s1_arsize  : s0_arsize;
    assign m_arburst = (state == S1_READ) ? s1_arburst : s0_arburst;
    assign m_arlock  = (state == S1_READ) ? s1_arlock  : s0_arlock;
    assign m_arcache = (state == S1_READ) ? s1_arcache : s0_arcache;
    assign m_arprot  = (state == S1_READ) ? s1_arprot  : s0_arprot;
    assign m_arvalid = (state == S1_READ) ? s1_arvalid : (state == S0_READ) ? s0_arvalid : 1'b0;

    assign s0_arready = (state == S0_READ) ? m_arready : 1'b0;
    assign s1_arready = (state == S1_READ) ? m_arready : 1'b0;

    // Demux 数据返回信号 (R Channel)
    assign s0_rid    = m_rid;
    assign s0_rdata  = m_rdata;
    assign s0_rresp  = m_rresp;
    assign s0_rlast  = m_rlast;
    assign s0_rvalid = (state == S0_READ) ? m_rvalid : 1'b0;

    assign s1_rid    = m_rid;
    assign s1_rdata  = m_rdata;
    assign s1_rresp  = m_rresp;
    assign s1_rlast  = m_rlast;
    assign s1_rvalid = (state == S1_READ) ? m_rvalid : 1'b0;

    assign m_rready  = (state == S1_READ) ? s1_rready : (state == S0_READ) ? s0_rready : 1'b1;

endmodule