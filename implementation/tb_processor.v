// tb of the processor. 
// Modify the load_words block in the middle and the expected outputs checks to change programs. 

`timescale 1ns / 1ps

module tb_processor;

    reg        clk;
    reg        reset_pi;
    reg [15:0] instr_data;
    reg        instr_valid;
    reg        load_done;
    wire       halted;
    wire       ready;

    localparam SIM_CYCLES      = 400;
    localparam EXEC_CHECK_AT   = 100;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    system_top dut (
        .clk            (clk),
        .reset_pi       (reset_pi),
        .instr_data_pi  (instr_data),
        .instr_valid_pi (instr_valid),
        .load_done_pi   (load_done),
        .halted_po      (halted),
        .ready_po       (ready)
    );

    integer i;
    integer err_count;
    integer exec_cycle;

    // Opcode mnemonic for trace readability (4 ASCII chars, left-aligned)
    function [4*8-1:0] opc_str;
        input [3:0] opc;
        begin
            case (opc)
                `NOP:    opc_str = "NOP ";
                `ADD:    opc_str = "ADD ";
                `NOT:    opc_str = "NOT ";
                `AND:    opc_str = "AND ";
                `XOR:    opc_str = "XOR ";
                `ADDI:   opc_str = "ADDI";
                `SR:     opc_str = "SR  ";
                `SL:     opc_str = "SL  ";
                `JAL:    opc_str = "JAL ";
                `RET:    opc_str = "RET ";
                `BNEZ:   opc_str = "BNEZ";
                `LD:     opc_str = "LD  ";
                `ST:     opc_str = "ST  ";
                `HALT:   opc_str = "HALT";
                default: opc_str = "??? ";
            endcase
        end
    endfunction

    // Compare actual vs expected, log result, bump err_count on mismatch
    task check16;
        input [8*20-1:0] label;
        input [15:0]     actual;
        input [15:0]     expected;
        begin
            if (actual !== expected) begin
                $display("  FAIL %0s : got %0d (0x%04h), expected %0d (0x%04h)",
                         label, $signed(actual), actual, $signed(expected), expected);
                err_count = err_count + 1;
            end else
                $display("  OK   %0s = %0d (0x%04h)", label, $signed(actual), actual);
        end
    endtask

    task load_word;
        input [15:0] word;
        begin
            instr_data  = word;
            instr_valid = 1'b1;
            @(negedge clk);
        end
    endtask


// program =============================================================================

    // load program, verify IMEM, print trace header
    initial begin
        err_count   = 0;
        exec_cycle  = 0;
        reset_pi    = 1'b1;
        instr_data  = 16'b0;
        instr_valid = 1'b0;
        load_done   = 1'b0;

        repeat (3) @(negedge clk);
        reset_pi = 1'b0;
        @(negedge clk);
        // use the following template to load instructions
        //        PC  Instruction                          interpretation

        load_word({`ADDI, 3'd1, 3'd0, 6'd5});        //  0  R1 = 5
        load_word({`ADDI, 3'd2, 3'd0, 6'd3});        //  1  R2 = 3
        load_word({`ADD,  3'd3, 3'd1, 3'd2, 3'b000});//  2  R3 = R1+R2 = 8
        load_word({`ST,   3'd0, 3'd3, 6'd0});        //  3  MEM[0] = R3
        load_word({`ADDI, 3'd4, 3'd0, 6'd0});        //  4  R4 = 0
        load_word({`LD,   3'd5, 3'd4, 6'd0});        //  5  R5 = MEM[0] (expect 8)
        load_word({`ADDI, 3'd1, 3'd1, 6'h3F});       //  6  R1 = R1-1 (loop body)
        load_word({`BNEZ, 3'd1, 3'd0, 6'b111110});   //  7  if R1!=0 goto PC 6
        load_word({`JAL,  3'd0, 9'b111111111});      //  8  JAL to self (infinite)
        load_word({`NOP,  12'h000});                 //  9  (unreachable)
        load_word({`HALT, 12'h000});                 // 10  (unreachable)
        load_word({`HALT, 12'h000});                 // 11
        load_word({`HALT, 12'h000});                 // 12
        load_word({`HALT, 12'h000});                 // 13
        load_word({`HALT, 12'h000});                 // 14
        load_word({`HALT, 12'h000});                 // 15

        instr_valid = 1'b0;
        load_done   = 1'b1;
        @(negedge clk);
        load_done = 1'b0;

        // verify every IMEM word after loading
        $display("");
        $display("===== IMEM Verification =====");
        check16("IMEM[00]", dut.imem.IMEM[ 0], {`ADDI, 3'd1, 3'd0, 6'd5});
        check16("IMEM[01]", dut.imem.IMEM[ 1], {`ADDI, 3'd2, 3'd0, 6'd3});
        check16("IMEM[02]", dut.imem.IMEM[ 2], {`ADD,  3'd3, 3'd1, 3'd2, 3'b000});
        check16("IMEM[03]", dut.imem.IMEM[ 3], {`ST,   3'd0, 3'd3, 6'd0});
        check16("IMEM[04]", dut.imem.IMEM[ 4], {`ADDI, 3'd4, 3'd0, 6'd0});
        check16("IMEM[05]", dut.imem.IMEM[ 5], {`LD,   3'd5, 3'd4, 6'd0});
        check16("IMEM[06]", dut.imem.IMEM[ 6], {`ADDI, 3'd1, 3'd1, 6'h3F});
        check16("IMEM[07]", dut.imem.IMEM[ 7], {`BNEZ, 3'd1, 3'd0, 6'b111110});
        check16("IMEM[08]", dut.imem.IMEM[ 8], {`JAL,  3'd0, 9'b111111111});
        check16("IMEM[09]", dut.imem.IMEM[ 9], {`NOP,  12'h000});

        for (i = 10; i < 16; i = i + 1) begin
            if (dut.imem.IMEM[i] !== {`HALT, 12'h000}) begin
                $display("  FAIL IMEM[%02d] : got 0x%04h, expected HALT", i, dut.imem.IMEM[i]);
                err_count = err_count + 1;
            end else
                $display("  OK   IMEM[%02d] = HALT", i);
        end

        // execution trace 
        $display("");
        $display("[%0t] Program loaded, execution begins", $time);
        $display("");
        $display("===== Phase 2: Execution Trace =====");
        $display(" Cyc| PC |  IF  |  ID  |  EX  | MEM  |  WB  |");
    end

    // Pipeline trace at the negegde clkb
    // (half-period after the pipeline update on posedge clk = negedge clkb)
    always @(negedge clk) begin
        if (dut.state == 1'b1) begin
            $write("C%03d| %2d | %s | %s | %s | %s | %s |",
                exec_cycle,
                dut.proc.pc_out,
                opc_str(dut.imem.IMEM[dut.proc.pc_out][15:12]),
                opc_str(dut.proc.if_id_instrM[15:12]),
                opc_str(dut.proc.id_ex_opcM),
                opc_str(dut.proc.ex_mem_opcM),
                opc_str(dut.proc.mem_wb_opcM)
            );
            if (dut.proc.stall_total) $write(" STL"); // shows proc stalls
            if (dut.proc.flush)       $write(" FLS"); // shows flushing piperegs
            if (dut.proc.rf_we && dut.proc.mem_wb_rdM != 3'b000)
                $write(" R%0d<=%0d", dut.proc.mem_wb_rdM, $signed(dut.proc.rf_wd));
            $write("\n");
            exec_cycle = exec_cycle + 1;
        end
    end
// checks ===============================================================================
    // final state checks
    initial begin
        wait (dut.state == 1'b1);
        repeat (EXEC_CHECK_AT) @(negedge clk);

        $display("");
        $display("===== Final State Check (cycle %0d) =====", exec_cycle);

        // Register file dump
        $display("--- Register File ---");
        for (i = 0; i < 8; i = i + 1)
            $display("  R%0d = %6d  (0x%04h)", i,
                     $signed(dut.proc.rf.regs[i]), dut.proc.rf.regs[i]);

        // Expected final state after BNEZ loop drains and JAL spins at PC 8:
        //   R0 = 0 (hardwired), R1 = 0 (decremented from 5),
        //   R2 = 3, R3 = 8, R4 = 0, R5 = 8 (loaded from MEM[0]),
        //   R6 = 0, R7 = 0  (never written).
        $display("--- Register Checks ---");
        check16("R0", dut.proc.rf.regs[0], 16'd0);
        check16("R1", dut.proc.rf.regs[1], 16'd0);
        check16("R2", dut.proc.rf.regs[2], 16'd3);
        check16("R3", dut.proc.rf.regs[3], 16'd8);
        check16("R4", dut.proc.rf.regs[4], 16'd0);
        check16("R5", dut.proc.rf.regs[5], 16'd8);
        check16("R6", dut.proc.rf.regs[6], 16'd0);
        check16("R7", dut.proc.rf.regs[7], 16'd0);

        // data cache ST wrote 8 to address 0.
        // addr 0 → cache index 0, word offset 0, tag 0.
        // DATA_ARRAY[0][15:0] should be 8, line should be valid and dirty.
        $display("--- Data Cache ---");
        $display("  DATA_ARRAY[0] = 0x%016h", dut.proc.dmem.DATA_ARRAY[0]);
        $display("  VALID[0]=%b  DIRTY[0]=%b  TAG[0]=%b",
                 dut.proc.dmem.VALID_ARRAY[0],
                 dut.proc.dmem.DIRTY_ARRAY[0],
                 dut.proc.dmem.TAG_ARRAY[0]);
        check16("cache[0] word0", dut.proc.dmem.DATA_ARRAY[0][15:0], 16'd8);

        // JAL at PC 8 is a self-loop (target = 8+1-1 = 8).
        // HALT at PC 10+ is unreachable because the JAL flush always squashes it.
        $display("--- Pipeline ---");
        $display("  pc_out   = %0d", dut.proc.pc_out);
        $display("  halted   = %b  (expected 0: HALT is unreachable past JAL loop)", halted);

        $display("");
        if (err_count == 0)
            $display("ALL CHECKS PASSED");
        else
            $display("%0d CHECK(S) FAILED", err_count);

        repeat (2) @(negedge clk);
        $stop;
    end

    // timeout
    initial begin
        repeat (SIM_CYCLES) @(negedge clk);
        $display("[%0t] TB timeout after %0d cycles", $time, SIM_CYCLES);
        $stop;
    end

endmodule
