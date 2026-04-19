`include "defines.vh"

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
    input  wire [15:0] imem_wdata_pi,

    input  wire [3:0]  dbg_addr_pi, // independent debug ports
    output wire [15:0] dbg_data_po
);

    reg [15:0] IMEM [0:15];

    assign instruction_po = IMEM[imem_addr_pi];
    assign dbg_data_po    = IMEM[dbg_addr_pi];

    always @(negedge clkb) begin
        if (imem_we_pi)
            IMEM[imem_waddr_pi] <= imem_wdata_pi;
    end

endmodule
