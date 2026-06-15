// AXI4 Slave Matrix Multiplier IP
// 4x4 matrix: C = A * B, 32-bit elements, 66-bit results
// No DSP, pure LUT/register/shift-and-add
module axi_matrix_mul (
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [4:0]  s_awid,
    input  wire [31:0] s_awaddr,
    input  wire [7:0]  s_awlen,
    input  wire [2:0]  s_awsize,
    input  wire [1:0]  s_awburst,
    input  wire        s_awlock,
    input  wire [3:0]  s_awcache,
    input  wire [2:0]  s_awprot,
    input  wire        s_awvalid,
    output reg         s_awready,
    input  wire [31:0] s_wdata,
    input  wire [3:0]  s_wstrb,
    input  wire        s_wlast,
    input  wire        s_wvalid,
    output reg         s_wready,
    output reg  [4:0]  s_bid,
    output reg  [1:0]  s_bresp,
    output reg         s_bvalid,
    input  wire        s_bready,
    input  wire [4:0]  s_arid,
    input  wire [31:0] s_araddr,
    input  wire [7:0]  s_arlen,
    input  wire [2:0]  s_arsize,
    input  wire [1:0]  s_arburst,
    input  wire        s_arlock,
    input  wire [3:0]  s_arcache,
    input  wire [2:0]  s_arprot,
    input  wire        s_arvalid,
    output reg         s_arready,
    output reg  [4:0]  s_rid,
    output reg  [31:0] s_rdata,
    output reg  [1:0]  s_rresp,
    output reg         s_rlast,
    output reg         s_rvalid,
    input  wire        s_rready
);

    // ==========================================
    // Register File
    // ==========================================
    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg [31:0] src_base_reg;
    reg [31:0] dst_base_reg;
    reg [31:0] group_num_reg;
    reg [31:0] reserved_reg [0:3];
    reg [31:0] a_data [0:15];
    reg [31:0] b_data [0:15];
    reg [65:0] c_accum [0:15];

    wire [31:0] c_data_lo  [0:15];
    wire [31:0] c_data_mid [0:15];
    wire [31:0] c_data_hi  [0:15];

    genvar gi, g, gi2;
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : c_split
            assign c_data_lo[gi]  = c_accum[gi][31:0];
            assign c_data_mid[gi] = c_accum[gi][63:32];
            assign c_data_hi[gi]  = {30'd0, c_accum[gi][65:64]};
        end
    endgenerate

    // ==========================================
    // AXI Write FSM
    // ==========================================
    reg aw_en, w_en, start_pulse;
    reg [31:0] capture_awaddr, capture_wdata;
    reg [4:0]  capture_awid;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_awready <= 1'b0; s_wready <= 1'b0; s_bvalid <= 1'b0;
            s_bresp <= 2'b00; s_bid <= 5'd0;
            aw_en <= 1'b0; w_en <= 1'b0; start_pulse <= 1'b0;
        end else begin
            start_pulse <= 1'b0;

            if (s_awvalid && !aw_en && !s_bvalid) begin
                s_awready <= 1'b1; capture_awaddr <= s_awaddr;
                capture_awid <= s_awid; aw_en <= 1'b1;
            end else s_awready <= 1'b0;

            if (s_wvalid && !w_en && !s_bvalid) begin
                s_wready <= 1'b1; capture_wdata <= s_wdata; w_en <= 1'b1;
            end else s_wready <= 1'b0;

            if (aw_en && w_en) begin
                s_bvalid <= 1'b1; s_bresp <= 2'b00; s_bid <= capture_awid;
                aw_en <= 1'b0; w_en <= 1'b0;
                case (capture_awaddr[9:0])
                    10'h000: begin ctrl_reg <= capture_wdata;
                        if (capture_wdata[0]) start_pulse <= 1'b1; end
                    10'h008: src_base_reg  <= capture_wdata;
                    10'h00C: dst_base_reg  <= capture_wdata;
                    10'h010: group_num_reg <= capture_wdata;
                    10'h020,10'h024,10'h028,10'h02C,10'h030,10'h034,10'h038,10'h03C,
                    10'h040,10'h044,10'h048,10'h04C,10'h050,10'h054,10'h058,10'h05C:
                        a_data[(capture_awaddr[9:0]-10'h020)>>2] <= capture_wdata;
                    10'h060,10'h064,10'h068,10'h06C,10'h070,10'h074,10'h078,10'h07C,
                    10'h080,10'h084,10'h088,10'h08C,10'h090,10'h094,10'h098,10'h09C:
                        b_data[(capture_awaddr[9:0]-10'h060)>>2] <= capture_wdata;
                endcase
            end else if (s_bvalid && s_bready) begin
                s_bvalid <= 1'b0;
            end
        end
    end

    // ==========================================
    // C_DATA read mux (combinational)
    // ==========================================
    reg [31:0] c_mux_arr [0:47];
    generate
        for (gi2 = 0; gi2 < 16; gi2 = gi2 + 1) begin : c_mux_gen
            always @(*) begin
                c_mux_arr[gi2*3 + 0] = c_data_lo[gi2];
                c_mux_arr[gi2*3 + 1] = c_data_mid[gi2];
                c_mux_arr[gi2*3 + 2] = c_data_hi[gi2];
            end
        end
    endgenerate
    wire [31:0] c_data_read_val = c_mux_arr[(capture_araddr - 10'h0A0) >> 2];

    // ==========================================
    // AXI Read FSM
    // ==========================================
    reg [4:0]  capture_arid;
    reg [9:0]  capture_araddr;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_arready <= 1'b0; s_rvalid <= 1'b0; s_rdata <= 32'd0;
            s_rresp <= 2'b00; s_rlast <= 1'b0; s_rid <= 5'd0;
        end else begin
            if (s_arvalid && !s_arready && !s_rvalid) begin
                s_arready <= 1'b1; capture_arid <= s_arid;
                capture_araddr <= s_araddr[9:0];
            end else s_arready <= 1'b0;

            if (s_arvalid && s_arready) begin
                s_rvalid <= 1'b1; s_rlast <= 1'b1; s_rid <= capture_arid;
                s_rresp <= 2'b00;
                case (capture_araddr)
                    10'h000: s_rdata <= ctrl_reg;
                    10'h004: s_rdata <= status_reg;
                    10'h008: s_rdata <= src_base_reg;
                    10'h00C: s_rdata <= dst_base_reg;
                    10'h010: s_rdata <= group_num_reg;
                    10'h020,10'h024,10'h028,10'h02C,10'h030,10'h034,10'h038,10'h03C,
                    10'h040,10'h044,10'h048,10'h04C,10'h050,10'h054,10'h058,10'h05C:
                        s_rdata <= a_data[(capture_araddr-10'h020)>>2];
                    10'h060,10'h064,10'h068,10'h06C,10'h070,10'h074,10'h078,10'h07C,
                    10'h080,10'h084,10'h088,10'h08C,10'h090,10'h094,10'h098,10'h09C:
                        s_rdata <= b_data[(capture_araddr-10'h060)>>2];
                    10'h0A0,10'h0A4,10'h0A8,10'h0AC,10'h0B0,10'h0B4,10'h0B8,10'h0BC,
                    10'h0C0,10'h0C4,10'h0C8,10'h0CC,10'h0D0,10'h0D4,10'h0D8,10'h0DC,
                    10'h0E0,10'h0E4,10'h0E8,10'h0EC,10'h0F0,10'h0F4,10'h0F8,10'h0FC,
                    10'h100,10'h104,10'h108,10'h10C,10'h110,10'h114,10'h118,10'h11C,
                    10'h120,10'h124,10'h128,10'h12C,10'h130,10'h134,10'h138,10'h13C,
                    10'h140,10'h144,10'h148,10'h14C,10'h150,10'h154,10'h158,10'h15C:
                        s_rdata <= c_data_read_val;
                    default: s_rdata <= 32'hDEADBEEF;
                endcase
            end else if (s_rvalid && s_rready) begin
                s_rvalid <= 1'b0;
            end
        end
    end

    // ==========================================
    // Multiply-Accumulate FSM
    // ==========================================
    localparam FSM_IDLE        = 4'd0;
    localparam FSM_LOAD        = 4'd1;
    localparam FSM_START_DELAY = 4'd2;
    localparam FSM_WAIT_MUL    = 4'd3;
    localparam FSM_ACCUM       = 4'd4;
    localparam FSM_NEXT_K      = 4'd5;
    localparam FSM_NEXT_ROW    = 4'd6;
    localparam FSM_DONE        = 4'd7;

    reg [3:0]  fsm_state;
    reg [1:0]  row, k;
    reg [31:0] a_val [0:3];
    reg [31:0] b_val [0:3];
    reg [3:0]  mul_start;
    wire [3:0] mul_busy, mul_done;
    wire [63:0] mul_product [0:3];

    generate
        for (g = 0; g < 4; g = g + 1) begin : gen_mul
            multiplier_32x32 u_mul (
                .clk    (aclk), .rst_n(aresetn),
                .start  (mul_start[g]),
                .a      (a_val[g]), .b(b_val[g]),
                .busy   (mul_busy[g]), .done(mul_done[g]),
                .product(mul_product[g])
            );
        end
    endgenerate

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            fsm_state <= FSM_IDLE; row <= 2'd0; k <= 2'd0;
            status_reg <= 32'd0; mul_start <= 4'b0;
        end else begin
            mul_start <= 4'b0;
            case (fsm_state)
                FSM_IDLE: begin
                    if (start_pulse) begin
                        fsm_state  <= FSM_LOAD; row <= 2'd0; k <= 2'd0;
                        status_reg <= 32'd1;
                        c_accum[0]<=66'd0; c_accum[1]<=66'd0; c_accum[2]<=66'd0; c_accum[3]<=66'd0;
                        c_accum[4]<=66'd0; c_accum[5]<=66'd0; c_accum[6]<=66'd0; c_accum[7]<=66'd0;
                        c_accum[8]<=66'd0; c_accum[9]<=66'd0; c_accum[10]<=66'd0; c_accum[11]<=66'd0;
                        c_accum[12]<=66'd0; c_accum[13]<=66'd0; c_accum[14]<=66'd0; c_accum[15]<=66'd0;
                    end
                end

                FSM_LOAD: begin
                    a_val[0] <= a_data[row*4 + k]; a_val[1] <= a_data[row*4 + k];
                    a_val[2] <= a_data[row*4 + k]; a_val[3] <= a_data[row*4 + k];
                    b_val[0] <= b_data[k*4 + 0]; b_val[1] <= b_data[k*4 + 1];
                    b_val[2] <= b_data[k*4 + 2]; b_val[3] <= b_data[k*4 + 3];
                    fsm_state <= FSM_START_DELAY;
                end

                FSM_START_DELAY: begin
                    mul_start <= 4'b1111;
                    fsm_state <= FSM_WAIT_MUL;
                end

                FSM_WAIT_MUL: begin
                    if (&mul_done) fsm_state <= FSM_ACCUM;
                end

                FSM_ACCUM: begin
                    c_accum[row*4 + 0] <= c_accum[row*4 + 0] + {2'd0, mul_product[0]};
                    c_accum[row*4 + 1] <= c_accum[row*4 + 1] + {2'd0, mul_product[1]};
                    c_accum[row*4 + 2] <= c_accum[row*4 + 2] + {2'd0, mul_product[2]};
                    c_accum[row*4 + 3] <= c_accum[row*4 + 3] + {2'd0, mul_product[3]};
                    fsm_state <= FSM_NEXT_K;
                end

                FSM_NEXT_K: begin
                    if (k == 2'd3) begin k <= 2'd0; fsm_state <= FSM_NEXT_ROW; end
                    else begin k <= k + 2'd1; fsm_state <= FSM_LOAD; end
                end

                FSM_NEXT_ROW: begin
                    if (row == 2'd3) begin fsm_state <= FSM_DONE; status_reg <= 32'd2; end
                    else begin row <= row + 2'd1; fsm_state <= FSM_LOAD; end
                end

                FSM_DONE: fsm_state <= FSM_IDLE;
                default:  fsm_state <= FSM_IDLE;
            endcase
        end
    end

endmodule
