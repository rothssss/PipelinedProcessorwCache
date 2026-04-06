// imem_addr_pi: word index 0..15 into this instruction memory (4-bit PC).

`include "defines.vh"

module instruction_mem (
    input  wire [3:0] imem_addr_pi,
    output wire [15:0] instruction_po
);

    reg [15:0] IMEM [0:15];

    assign instruction_po = IMEM[imem_addr_pi];

    integer ii;
    initial begin
        for (ii = 0; ii < 16; ii = ii + 1)
            IMEM[ii] = 16'h0000;
        IMEM[0]  = {`ADDI, 3'd1, 3'd0, 6'd5};
        IMEM[1]  = {`ADDI, 3'd2, 3'd0, 6'd3};
        IMEM[2]  = {`ADD,  3'd3, 3'd1, 3'd2, 3'b000};
        IMEM[3]  = {`ST,   3'd0, 3'd3, 6'd0};
        IMEM[4]  = {`ADDI, 3'd4, 3'd0, 6'd0};
        IMEM[5]  = {`LD,   3'd5, 3'd4, 6'd0};
        IMEM[6]  = {`ADDI, 3'd1, 3'd1, 6'h3F};
        IMEM[7]  = {`BNEZ, 3'd1, 3'd0, 6'b111110};
        IMEM[8]  = {`JAL, 3'd0, 9'b111111111};
        IMEM[9]  = {`NOP,  12'h000};
        IMEM[10] = {`HALT, 12'h000};
        IMEM[11] = {`HALT, 12'h000};
        IMEM[12] = {`HALT, 12'h000};
        IMEM[13] = {`HALT, 12'h000};
        IMEM[14] = {`HALT, 12'h000};
        IMEM[15] = {`HALT, 12'h000};
    end

endmodule
