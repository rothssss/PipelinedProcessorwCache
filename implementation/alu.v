// branchCond_po: |op1_pi (BNEZ tests rs != 0 using forwarded op1).

`include "defines.vh"

module alu (
    input wire [15:0] op1_pi,
    input wire [15:0] op2_pi,
    input wire [3:0] aluFunc_pi,
    input wire [15:0] offset_pi,
    input wire shift_modifier_pi,
    output reg [15:0] result_po,
    output wire branchCond_po
);

    always @(*) begin
        case (aluFunc_pi)
            `ADD:  result_po = op1_pi + op2_pi;
            `NOT:  result_po = ~op1_pi;
            `AND:  result_po = op1_pi & op2_pi;
            `XOR:  result_po = op1_pi ^ op2_pi;
            `ADDI,
            `LD,
            `ST:   result_po = op1_pi + offset_pi;
            `BNEZ: result_po = 16'b0;
            `SR:   result_po = shift_modifier_pi
                               ? ($signed(op1_pi) >>> offset_pi[4:0])
                               : (op1_pi >> offset_pi[4:0]);
            `SL:   result_po = op1_pi << offset_pi[4:0];
            default: result_po = 16'b0;
        endcase
    end

    assign branchCond_po = |op1_pi;

endmodule
