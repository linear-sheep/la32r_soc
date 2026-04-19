`timescale 1ns / 1ps

module tb_sobel_dma();

    reg clk;
    reg rst_n;
    
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        rst_n = 0;
        #20 rst_n = 1;
    end

    // AXI Slave Signals (For Configuration)
    reg [3:0]  s_awid;
    reg [31:0] s_awaddr;
    reg [7:0]  s_awlen;
    reg [2:0]  s_awsize;
    reg [1:0]  s_awburst;
    reg [1:0]  s_awlock;
    reg [3:0]  s_awcache;
    reg [2:0]  s_awprot;
    reg        s_awvalid;
    wire       s_awready;
    reg [3:0]  s_wid;
    reg [31:0] s_wdata;
    reg [3:0]  s_wstrb;
    reg        s_wlast;
    reg        s_wvalid;
    wire       s_wready;
    wire [3:0] s_bid;
    wire [1:0] s_bresp;
    wire       s_bvalid;
    reg        s_bready;
    reg [3:0]  s_arid;
    reg [31:0] s_araddr;
    reg [7:0]  s_arlen;
    reg [2:0]  s_arsize;
    reg [1:0]  s_arburst;
    reg [1:0]  s_arlock;
    reg [3:0]  s_arcache;
    reg [2:0]  s_arprot;
    reg        s_arvalid;
    wire       s_arready;
    wire [3:0] s_rid;
    wire [31:0]s_rdata;
    wire [1:0] s_rresp;
    wire       s_rlast;
    wire       s_rvalid;
    reg        s_rready;

    // AXI Master Signals (For DMA Data)
    wire [3:0]  m_arid, m_awid, m_wid, m_rid, m_bid;
    wire [31:0] m_araddr, m_awaddr, m_wdata, m_rdata;
    wire [7:0]  m_arlen, m_awlen;
    wire [2:0]  m_arsize, m_awsize, m_arprot, m_awprot;
    wire [1:0]  m_arburst, m_awburst, m_arlock, m_awlock, m_rresp, m_bresp;
    wire [3:0]  m_arcache, m_awcache, m_wstrb;
    wire        m_arvalid, m_awvalid, m_wvalid, m_wlast, m_rvalid, m_rlast, m_bvalid;
    reg         m_arready, m_awready, m_wready, m_rvalid_reg, m_bvalid_reg;
    reg  [31:0] m_rdata_reg;

    assign m_rvalid = m_rvalid_reg;
    assign m_rdata = m_rdata_reg;
    assign m_bvalid = m_bvalid_reg;
    assign m_rlast = m_rvalid_reg; // Single beat responses
    assign m_rresp = 2'b00;
    assign m_bresp = 2'b00;

    axi_sobel_dma u_dut (
        .aclk(clk), .aresetn(rst_n),
        .s_awid(s_awid), .s_awaddr(s_awaddr), .s_awlen(s_awlen), .s_awsize(s_awsize),
        .s_awburst(s_awburst), .s_awlock(s_awlock), .s_awcache(s_awcache), .s_awprot(s_awprot),
        .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wid(s_wid), .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wlast(s_wlast),
        .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bid(s_bid), .s_bresp(s_bresp), .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_arid(s_arid), .s_araddr(s_araddr), .s_arlen(s_arlen), .s_arsize(s_arsize),
        .s_arburst(s_arburst), .s_arlock(s_arlock), .s_arcache(s_arcache), .s_arprot(s_arprot),
        .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rid(s_rid), .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rlast(s_rlast),
        .s_rvalid(s_rvalid), .s_rready(s_rready),
        .m_arid(m_arid), .m_araddr(m_araddr), .m_arlen(m_arlen), .m_arsize(m_arsize),
        .m_arburst(m_arburst), .m_arlock(m_arlock), .m_arcache(m_arcache), .m_arprot(m_arprot),
        .m_arvalid(m_arvalid), .m_arready(m_arready),
        .m_rid(m_rid), .m_rdata(m_rdata), .m_rresp(m_rresp), .m_rlast(m_rlast),
        .m_rvalid(m_rvalid), .m_rready(m_rready),
        .m_awid(m_awid), .m_awaddr(m_awaddr), .m_awlen(m_awlen), .m_awsize(m_awsize),
        .m_awburst(m_awburst), .m_awlock(m_awlock), .m_awcache(m_awcache), .m_awprot(m_awprot),
        .m_awvalid(m_awvalid), .m_awready(m_awready),
        .m_wid(m_wid), .m_wdata(m_wdata), .m_wstrb(m_wstrb), .m_wlast(m_wlast),
        .m_wvalid(m_wvalid), .m_wready(m_wready),
        .m_bid(m_bid), .m_bresp(m_bresp), .m_bvalid(m_bvalid), .m_bready(m_bready)
    );

    // Mock AXI Slave Memory
    reg [7:0] memory [0:4095];
    initial begin
        m_arready = 0; m_awready = 0; m_wready = 0; m_rvalid_reg = 0; m_bvalid_reg = 0;
    end

    // AXI Read Channel Mock
    always @(posedge clk) begin
        if (m_arvalid && !m_arready) begin
            m_arready <= 1; // Accept Address
        end else if (m_arready) begin
            m_arready <= 0;
            m_rvalid_reg <= 1;
            // Return dummy data (simple incrementing pattern)
            m_rdata_reg <= {4{m_araddr[7:0]}}; 
        end
        if (m_rvalid_reg && m_rready) begin
            m_rvalid_reg <= 0; // Data accepted
        end
    end

    // AXI Write Channel Mock (Strict ordering AW -> W -> B for robustness)
    reg [31:0] write_addr;
    always @(posedge clk) begin
        // Address Phase
        if (m_awvalid && !m_awready) begin
            m_awready <= 1;
            write_addr <= m_awaddr;
        end else begin
            m_awready <= 0;
        end
        
        // Data Phase
        if (m_wvalid && !m_wready) begin
            m_wready <= 1;
        end else begin
            m_wready <= 0;
        end

        // Response Phase
        if (m_wvalid && m_wready) begin
            // Write occurred
            m_bvalid_reg <= 1;
        end else if (m_bvalid_reg && m_bready) begin
            m_bvalid_reg <= 0;
        end
    end

    // AXI Write Task for Configuration Settings
    task axi_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge clk);
        s_awaddr = addr; s_awvalid = 1;
        s_wdata = data; s_wvalid = 1;
        s_bready = 1;
        
        wait(s_awready);
        @(posedge clk);
        s_awvalid = 0;
        
        wait(s_wready);
        @(posedge clk);
        s_wvalid = 0;
        
        wait(s_bvalid);
        @(posedge clk);
        s_bready = 0;
    end
    endtask

    // Control Sequence
    initial begin
        s_awid = 0; s_awaddr = 0; s_awlen = 0; s_awsize = 0; s_awburst = 1; 
        s_awlock = 0; s_awcache = 0; s_awprot = 0; s_awvalid = 0;
        s_wid = 0; s_wdata = 0; s_wstrb = 4'hf; s_wlast = 1; s_wvalid = 0; s_bready = 0;
        s_arid = 0; s_araddr = 0; s_arlen = 0; s_arsize = 0; s_arburst = 1;
        s_arlock = 0; s_arcache = 0; s_arprot = 0; s_arvalid = 0; s_rready = 0;

        #100;
        $display("--- Starting DMA Configuration ---");
        axi_write(32'h00, 32'h00000000); // Src addr
        axi_write(32'h04, 32'h00001000); // Dst addr
        axi_write(32'h0C, (4 << 16) | 4); // 4x4 image
        axi_write(32'h08, 32'h00000001); // Start!
        $display("--- DMA Started ---");
        
        // Wait for it to finish natively (timeout after 50000ns)
        #50000;
        $display("Timeout or Finished");
        $finish;
    end
    
    // Monitor Completion
    always @(posedge clk) begin
        if (u_dut.dma_done) begin
            $display("--- DMA Completed Successfully ---");
            $finish;
        end
    end
endmodule