// clkb: write edge. rdata*_po: async read with same-cycle bypass from write port.

module reg_file (
    input wire clkb,
    input wire reset_pi,
    input wire [2:0] raddr1_pi,
    input wire [2:0] raddr2_pi,
    input wire [2:0] waddr_pi,
    input wire we_pi,
    input wire [15:0] wdata_pi,
    output wire [15:0] rdata1_po,
    output wire [15:0] rdata2_po,
    // independent debug ports
    input  wire [2:0]  dbg_addr_pi,
    output wire [15:0] dbg_data_po
);

    reg [15:0] regs [0:7];
    integer i;

    wire [15:0] r1_raw = (raddr1_pi == 3'b000) ? 16'b0 : regs[raddr1_pi];
    wire [15:0] r2_raw = (raddr2_pi == 3'b000) ? 16'b0 : regs[raddr2_pi];

    assign rdata1_po = (we_pi && (waddr_pi == raddr1_pi) && (raddr1_pi != 3'b000))
                       ? wdata_pi : r1_raw;
    assign rdata2_po = (we_pi && (waddr_pi == raddr2_pi) && (raddr2_pi != 3'b000))
                       ? wdata_pi : r2_raw;

    assign dbg_data_po = regs[dbg_addr_pi];

    // Sync reset on negedge clkb.
    always @(negedge clkb) begin
        if (reset_pi) begin
            for (i = 0; i < 8; i = i + 1)
                regs[i] <= 16'b0;
        end else if (we_pi && (waddr_pi != 3'b000))
            regs[waddr_pi] <= wdata_pi;
    end

endmodule
