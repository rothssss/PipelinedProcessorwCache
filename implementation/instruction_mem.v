// Opcode and constant definitions (global for the compilation unit).
// This file must be compiled first so all other modules see these macros.

`ifndef DEFINES_VH
`define DEFINES_VH

`define NOP   4'b0000
`define ADD   4'b0001
`define NOT   4'b0010
`define AND   4'b0011
`define XOR   4'b0100
`define ADDI  4'b0101
`define SR    4'b0110
`define SL    4'b0111
`define JAL   4'b1000
`define RET   4'b1001
`define BNEZ  4'b1010
`define LD    4'b1011
`define ST    4'b1100
`define HALT  4'b1111

`define STACK_BASE 5'd24

`endif

// Async read, sync write (negedge clkb). 16 words x 16 bits.
// imem_addr_pi:  word-address for the read port (driven by processor PC).
// imem_we_pi:    write-enable for the serial loader.
// imem_waddr_pi: word-address for the write port (driven by loader counter).
// imem_wdata_pi: instruction word to store.

module instruction_mem (
    input  wire        clkb,
    input  wire [3:0]  imem_addr_pi,
    output wire [15:0] instruction_po,
    input  wire        imem_we_pi,
    input  wire [3:0]  imem_waddr_pi,
    input  wire [15:0] imem_wdata_pi
);

    reg [15:0] IMEM [0:15];

    assign instruction_po = IMEM[imem_addr_pi];

    integer ii;
    initial begin
        for (ii = 0; ii < 16; ii = ii + 1)
            IMEM[ii] = 16'h0000;
    end

    always @(negedge clkb) begin
        if (imem_we_pi)
            IMEM[imem_waddr_pi] <= imem_wdata_pi;
    end

endmodule
