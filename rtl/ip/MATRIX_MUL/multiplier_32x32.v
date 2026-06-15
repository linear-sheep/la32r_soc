// 32-bit x 32-bit shift-and-add multiplier (no DSP)
// Produces 64-bit product in 32 cycles
module multiplier_32x32 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,         // Pulse to begin
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire        busy,
    output reg         done,          // 1-cycle pulse on completion
    output wire [63:0] product
);
    localparam IDLE = 2'd0, COMPUTE = 2'd1, DONE_ST = 2'd2;

    reg [1:0]  state, next_state;
    reg [5:0]  counter;
    reg [63:0] acc;
    reg [31:0] shift_b;
    reg [63:0] shift_a;

    assign busy  = (state == COMPUTE);
    assign product = acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            counter <= 6'd0;
            acc     <= 64'd0;
            shift_b <= 32'd0;
            shift_a <= 64'd0;
            done    <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        acc     <= 64'd0;
                        shift_b <= b;
                        shift_a <= {32'd0, a};
                        counter <= 6'd0;
                    end
                end

                COMPUTE: begin
                    if (shift_b[0])
                        acc <= acc + shift_a;
                    shift_b   <= shift_b >> 1;
                    shift_a   <= shift_a << 1;
                    counter   <= counter + 6'd1;
                end

                DONE_ST: begin
                    done  <= 1'b1;
                end

                default: done <= 1'b0;
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:     if (start) next_state = COMPUTE;
            COMPUTE:  if (counter == 6'd31) next_state = DONE_ST;
            DONE_ST:  next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end
endmodule
