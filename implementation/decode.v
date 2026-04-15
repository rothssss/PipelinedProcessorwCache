// control_po: {JAL,RET,Branch,Store,Load,ALU1op,ALU2op}. 
// LD layout: rd=[11:9], rs=[8:6], imm6=[5:0] (6-bit offset changed from original 9-bit in doc)

module decode (
    input  wire [15:0] instr_pi,
    output wire [3:0]  opCode_po,
    output wire [2:0]  rs_po,
    output wire [2:0]  rt_po,
    output wire [15:0] offset_po,
    output wire [6:0]  control_po,
    output wire [2:0]  destReg_po,
    output wire        shift_modifier_po,
    output wire        writeEnable_po,
    output wire        isHalt_po
);

    wire [3:0] op;
    wire       ALU2op, ALU1op, Load, Store, Branch, isRET, isJAL;
    reg  [2:0] rs, rt, destReg;
    reg  [15:0] offset;
    reg         shift_mod;

    assign op = instr_pi[15:12];
    assign opCode_po = op;

    always @(*) begin
        rs = 3'b0;
        rt = 3'b0;
        destReg = 3'b0;
        offset = 16'b0;
        shift_mod = 1'b0;
        case (op)
            `NOP, `HALT: ;
            `ADD, `NOT, `AND, `XOR: begin
                destReg = instr_pi[11:9];
                rs = instr_pi[8:6];
                rt = instr_pi[5:3];
            end
            `ADDI: begin
                destReg = instr_pi[11:9];
                rs = instr_pi[8:6];
                offset = {{10{instr_pi[5]}}, instr_pi[5:0]};
            end
            `RET: begin
                rs = instr_pi[8:6];
            end
            `SR, `SL: begin
                destReg = instr_pi[11:9];
                rs = instr_pi[8:6];
                shift_mod = instr_pi[5];
                offset = {{11{instr_pi[4]}}, instr_pi[4:0]};
            end
            `JAL: begin
                destReg = instr_pi[11:9];
                offset = {{7{instr_pi[8]}}, instr_pi[8:0]};
            end
            `BNEZ, `ST: begin
                rs = instr_pi[11:9];
                rt = instr_pi[8:6];
                offset = {{10{instr_pi[5]}}, instr_pi[5:0]};
            end
            `LD: begin
                destReg = instr_pi[11:9];
                rs      = instr_pi[8:6];
                offset  = {{10{instr_pi[5]}}, instr_pi[5:0]};
            end
            default: ;
        endcase
    end

    assign rs_po = rs;
    assign rt_po = rt;
    assign destReg_po = destReg;
    assign offset_po = offset;
    assign shift_modifier_po = shift_mod;

    assign ALU2op = (op == `ADD || op == `NOT || op == `AND || op == `XOR);
    assign ALU1op = (op == `ADDI || op == `SR || op == `SL);
    assign Load   = (op == `LD);
    assign Store  = (op == `ST);
    assign Branch = (op == `BNEZ);
    assign isRET  = (op == `RET);
    assign isJAL  = (op == `JAL);

    assign control_po = {isJAL, isRET, Branch, Store, Load, ALU1op, ALU2op};

    // Reg write: R-type (incl NOT), I-type, JAL, LD . not ST/RET/Branch/NOP/HALT.
    assign writeEnable_po = (op != `NOP) && (op != `HALT) && (op != `ST)
                         && (op != `RET) && (op != `BNEZ);

    assign isHalt_po = (op == `HALT);

endmodule
