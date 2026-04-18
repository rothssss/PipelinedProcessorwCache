// Testbench for PipelinedProcessorwCache with two-phase clock and debug port.
// Loads a program via the serial interface, runs it, then reads back
// registers, IMEM, DMEM, cache state, and PC through the debug port.

`timescale 1ns / 1ps

module tb_processor;

    reg        clka;
    reg        clkb;
    reg        reset_pi;
    reg [15:0] instr_data;
    reg        instr_valid;
    reg        load_done;
    wire       halted;
    wire       ready;

    reg  [6:0]  dbg_addr;
    wire [15:0] dbg_data;

    localparam SIM_CYCLES    = 600;
    localparam EXEC_CHECK_AT = 200;

    // Non-overlapping two-phase clock: 20 ns period (50 MHz)
    //   t+0  : dead zone (both low)
    //   t+2  : clka rises
    //   t+7  : clka falls  (negedge clka)
    //   t+10 : clkb rises
    //   t+15 : clkb falls  (negedge clkb)
    //   t+17 : dead zone start, next period at t+20
    initial begin clka = 0; clkb = 0; end
    always begin
        #2  clka = 1;
        #5  clka = 0;
        #3  clkb = 1;
        #5  clkb = 0;
        #5;
    end

    system_top dut (
        .clka           (clka),
        .clkb           (clkb),
        .reset_pi       (reset_pi),
        .instr_data_pi  (instr_data),
        .instr_valid_pi (instr_valid),
        .load_done_pi   (load_done),
        .halted_po      (halted),
        .ready_po       (ready),
        .dbg_addr_pi    (dbg_addr),
        .dbg_data_po    (dbg_data)
    );

    integer i;
    integer err_count;
    integer exec_cycle;

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

    // Debug read helper: set address, wait for combinational propagation, return data
    task dbg_read;
        input  [6:0]  addr;
        output [15:0] data;
        begin
            dbg_addr = addr;
            #1;
            data = dbg_data;
        end
    endtask

    // Load one instruction word on the serial interface
    task load_word;
        input [15:0] word;
        begin
            @(negedge clka);
            instr_data  = word;
            instr_valid = 1'b1;
            @(negedge clkb);
        end
    endtask


// Program loading and IMEM verification via debug port
    reg [15:0] dbg_tmp;

    initial begin
        err_count   = 0;
        exec_cycle  = 0;
        dbg_addr    = 7'b0;
        reset_pi    = 1'b1;
        instr_data  = 16'b0;
        instr_valid = 1'b0;
        load_done   = 1'b0;

        repeat (3) @(negedge clkb);
        reset_pi = 1'b0;
        @(negedge clkb);

        // Recursive sum(n) = n + sum(n-1), sum(0) = 0.
        // N = 5, sp starts at 0, stride = 4 per stack frame so that recursion
        // forces a cache eviction (line 0 tag=0 evicted by tag=1 at addr 16).
        // Expected final R1 = 1+2+3+4+5 = 15.
        //
        // Register usage: R0=zero, R1=n/result, R2=sp, R3=temp, R7=return address.
        //
        //        PC  Instruction                              Meaning
        load_word({`ADDI, 3'd1, 3'd0, 6'd5});             //  0  R1 = n = 5
        load_word({`ADDI, 3'd2, 3'd0, 6'd0});             //  1  R2 = sp = 0
        load_word({`JAL,  3'd7, 9'd1});                   //  2  R7=3; call sum (PC<=4)
        load_word({`JAL,  3'd0, 9'b111111111});           //  3  self-loop (result in R1)
        // sum:
        load_word({`BNEZ, 3'd1, 3'd0, 6'd1});             //  4  if n!=0 goto recurse
        load_word({`RET,  3'd0, 3'd7, 6'd0});             //  5  base: n==0, R1=0, return
        // recurse:
        load_word({`ST,   3'd2, 3'd1, 6'd0});             //  6  MEM[sp+0] = n
        load_word({`ST,   3'd2, 3'd7, 6'd1});             //  7  MEM[sp+1] = ra
        load_word({`ADDI, 3'd2, 3'd2, 6'd4});             //  8  sp += 4
        load_word({`ADDI, 3'd1, 3'd1, 6'h3F});            //  9  n  -= 1
        load_word({`JAL,  3'd7, 9'b111111001});           // 10  R7=11; recursive call (-7)
        load_word({`ADDI, 3'd2, 3'd2, 6'b111100});        // 11  sp -= 4
        load_word({`LD,   3'd3, 3'd2, 6'd0});             // 12  R3 = saved n
        load_word({`LD,   3'd7, 3'd2, 6'd1});             // 13  R7 = saved ra
        load_word({`ADD,  3'd1, 3'd1, 3'd3, 3'b000});     // 14  R1 = subsum + n
        load_word({`RET,  3'd0, 3'd7, 6'd0});             // 15  return

        instr_valid = 1'b0;
        load_done   = 1'b1;
        @(negedge clkb);
        load_done = 1'b0;

        // Verify IMEM contents through debug port (addresses 0x10-0x1F)
        $display("");
        $display("===== IMEM Verification (via debug port) =====");
        dbg_read(7'h10, dbg_tmp); check16("IMEM[00]", dbg_tmp, {`ADDI, 3'd1, 3'd0, 6'd5});
        dbg_read(7'h11, dbg_tmp); check16("IMEM[01]", dbg_tmp, {`ADDI, 3'd2, 3'd0, 6'd0});
        dbg_read(7'h12, dbg_tmp); check16("IMEM[02]", dbg_tmp, {`JAL,  3'd7, 9'd1});
        dbg_read(7'h13, dbg_tmp); check16("IMEM[03]", dbg_tmp, {`JAL,  3'd0, 9'b111111111});
        dbg_read(7'h14, dbg_tmp); check16("IMEM[04]", dbg_tmp, {`BNEZ, 3'd1, 3'd0, 6'd1});
        dbg_read(7'h15, dbg_tmp); check16("IMEM[05]", dbg_tmp, {`RET,  3'd0, 3'd7, 6'd0});
        dbg_read(7'h16, dbg_tmp); check16("IMEM[06]", dbg_tmp, {`ST,   3'd2, 3'd1, 6'd0});
        dbg_read(7'h17, dbg_tmp); check16("IMEM[07]", dbg_tmp, {`ST,   3'd2, 3'd7, 6'd1});
        dbg_read(7'h18, dbg_tmp); check16("IMEM[08]", dbg_tmp, {`ADDI, 3'd2, 3'd2, 6'd4});
        dbg_read(7'h19, dbg_tmp); check16("IMEM[09]", dbg_tmp, {`ADDI, 3'd1, 3'd1, 6'h3F});
        dbg_read(7'h1A, dbg_tmp); check16("IMEM[10]", dbg_tmp, {`JAL,  3'd7, 9'b111111001});
        dbg_read(7'h1B, dbg_tmp); check16("IMEM[11]", dbg_tmp, {`ADDI, 3'd2, 3'd2, 6'b111100});
        dbg_read(7'h1C, dbg_tmp); check16("IMEM[12]", dbg_tmp, {`LD,   3'd3, 3'd2, 6'd0});
        dbg_read(7'h1D, dbg_tmp); check16("IMEM[13]", dbg_tmp, {`LD,   3'd7, 3'd2, 6'd1});
        dbg_read(7'h1E, dbg_tmp); check16("IMEM[14]", dbg_tmp, {`ADD,  3'd1, 3'd1, 3'd3, 3'b000});
        dbg_read(7'h1F, dbg_tmp); check16("IMEM[15]", dbg_tmp, {`RET,  3'd0, 3'd7, 6'd0});

        $display("");
        $display("[%0t] Program loaded, execution begins", $time);
        $display("");
        $display("===== Execution Trace =====");
        $display(" Cyc| PC |  IF  |  ID  |  EX  | MEM  |  WB  |");
    end

    // Pipeline trace (uses hierarchical refs, simulation-only diagnostic)
    always @(negedge clkb) begin
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
            if (dut.proc.stall_total) $write(" STL");
            if (dut.proc.flush)       $write(" FLS");
            if (dut.proc.rf_we && dut.proc.mem_wb_rdM != 3'b000)
                $write(" R%0d<=%0d", dut.proc.mem_wb_rdM, $signed(dut.proc.rf_wd));
            $write("\n");
            exec_cycle = exec_cycle + 1;
        end
    end


// Final state checks: everything read through the debug port
    initial begin
        wait (dut.state == 1'b1);
        repeat (EXEC_CHECK_AT) @(negedge clkb);

        $display("");
        $display("===== Final State Check (cycle %0d, via debug port) =====", exec_cycle);

        // Register file (debug addresses 0x00-0x07)
        $display("--- Register File ---");
        for (i = 0; i < 8; i = i + 1) begin
            dbg_read(i[6:0], dbg_tmp);
            $display("  R%0d = %6d  (0x%04h)", i, $signed(dbg_tmp), dbg_tmp);
        end

        // Expected final state after sum(5) returns and PC settles on self-loop at PC 3:
        //   R1 = 15 (the result), R2 = 0 (sp restored), R3 = 5 (last LD value),
        //   R7 = 3 (main's return address, restored from cache during final unwind),
        //   R0/R4/R5/R6 = 0 (never written).
        $display("--- Register Checks ---");
        dbg_read(7'h00, dbg_tmp); check16("R0", dbg_tmp, 16'd0);
        dbg_read(7'h01, dbg_tmp); check16("R1 (sum)", dbg_tmp, 16'd15);
        dbg_read(7'h02, dbg_tmp); check16("R2 (sp)",  dbg_tmp, 16'd0);
        dbg_read(7'h03, dbg_tmp); check16("R3",        dbg_tmp, 16'd5);
        dbg_read(7'h04, dbg_tmp); check16("R4",        dbg_tmp, 16'd0);
        dbg_read(7'h05, dbg_tmp); check16("R5",        dbg_tmp, 16'd0);
        dbg_read(7'h06, dbg_tmp); check16("R6",        dbg_tmp, 16'd0);
        dbg_read(7'h07, dbg_tmp); check16("R7 (ra)",   dbg_tmp, 16'd3);

        // Cache state after execution:
        //   Line 0: tag=0, valid=1, dirty=0 -- reinstalled clean during final LD [0] miss
        //           data = [5, 3, 0, 0]   (the first stack frame's n and ra)
        //   Line 1: tag=0, valid=1, dirty=1 -- holds frame for sum(4): [4, 11, 0, 0]
        //   Line 2: tag=0, valid=1, dirty=1 -- holds frame for sum(3): [3, 11, 0, 0]
        //   Line 3: tag=0, valid=1, dirty=1 -- holds frame for sum(2): [2, 11, 0, 0]
        $display("--- Data Cache (via debug port) ---");
        dbg_read(7'h40, dbg_tmp); check16("cache[0] w0 (n=5)",  dbg_tmp, 16'd5);
        dbg_read(7'h41, dbg_tmp); check16("cache[0] w1 (ra=3)", dbg_tmp, 16'd3);
        dbg_read(7'h44, dbg_tmp); check16("cache[1] w0 (n=4)",  dbg_tmp, 16'd4);
        dbg_read(7'h45, dbg_tmp); check16("cache[1] w1 (ra=11)",dbg_tmp, 16'd11);
        dbg_read(7'h48, dbg_tmp); check16("cache[2] w0 (n=3)",  dbg_tmp, 16'd3);
        dbg_read(7'h49, dbg_tmp); check16("cache[2] w1 (ra=11)",dbg_tmp, 16'd11);
        dbg_read(7'h4C, dbg_tmp); check16("cache[3] w0 (n=2)",  dbg_tmp, 16'd2);
        dbg_read(7'h4D, dbg_tmp); check16("cache[3] w1 (ra=11)",dbg_tmp, 16'd11);

        $display("--- Cache Metadata (via debug port) ---");
        dbg_read(7'h50, dbg_tmp);
        $display("  META[0] = 0x%04h  (valid=%b dirty=%b tag=%b)",
                 dbg_tmp, dbg_tmp[2], dbg_tmp[1], dbg_tmp[0]);
        check16("META[0]", dbg_tmp, {13'b0, 1'b1, 1'b0, 1'b0});
        dbg_read(7'h51, dbg_tmp);
        $display("  META[1] = 0x%04h  (valid=%b dirty=%b tag=%b)",
                 dbg_tmp, dbg_tmp[2], dbg_tmp[1], dbg_tmp[0]);
        check16("META[1]", dbg_tmp, {13'b0, 1'b1, 1'b1, 1'b0});
        dbg_read(7'h52, dbg_tmp);
        $display("  META[2] = 0x%04h  (valid=%b dirty=%b tag=%b)",
                 dbg_tmp, dbg_tmp[2], dbg_tmp[1], dbg_tmp[0]);
        check16("META[2]", dbg_tmp, {13'b0, 1'b1, 1'b1, 1'b0});
        dbg_read(7'h53, dbg_tmp);
        $display("  META[3] = 0x%04h  (valid=%b dirty=%b tag=%b)",
                 dbg_tmp, dbg_tmp[2], dbg_tmp[1], dbg_tmp[0]);
        check16("META[3]", dbg_tmp, {13'b0, 1'b1, 1'b1, 1'b0});

        // DMEM backing store: two dirty writebacks occurred on line 0.
        //   First eviction (sum(1) ST [16]) wrote old tag=0 line back to DMEM[0..3].
        //   Second eviction (sum(5) LD [0]) wrote tag=1 line back to DMEM[16..19].
        $display("--- DMEM Backing Store (via debug port) ---");
        dbg_read(7'h20, dbg_tmp); check16("DMEM[0]  (sum5 n)",  dbg_tmp, 16'd5);
        dbg_read(7'h21, dbg_tmp); check16("DMEM[1]  (sum5 ra)", dbg_tmp, 16'd3);
        dbg_read(7'h22, dbg_tmp); check16("DMEM[2]",            dbg_tmp, 16'd0);
        dbg_read(7'h23, dbg_tmp); check16("DMEM[3]",            dbg_tmp, 16'd0);
        dbg_read(7'h30, dbg_tmp); check16("DMEM[16] (sum1 n)",  dbg_tmp, 16'd1);
        dbg_read(7'h31, dbg_tmp); check16("DMEM[17] (sum1 ra)", dbg_tmp, 16'd11);
        // DMEM[4..15] should still be 0 because those cache lines are still dirty
        // in cache and never been evicted/written back.
        dbg_read(7'h24, dbg_tmp); check16("DMEM[4]  (still 0)", dbg_tmp, 16'd0);
        dbg_read(7'h28, dbg_tmp); check16("DMEM[8]  (still 0)", dbg_tmp, 16'd0);
        dbg_read(7'h2C, dbg_tmp); check16("DMEM[12] (still 0)", dbg_tmp, 16'd0);

        // PC via debug address 0x58. After RET from sum, PC settles on the JAL self-loop at PC=3.
        $display("--- Pipeline ---");
        dbg_read(7'h58, dbg_tmp);
        $display("  PC (debug) = %0d", dbg_tmp);
        check16("PC", dbg_tmp, 16'd3);
        $display("  halted     = %b  (expected 0: HALT never decoded)", halted);

        $display("");
        if (err_count == 0)
            $display("ALL CHECKS PASSED");
        else
            $display("%0d CHECK(S) FAILED", err_count);

        repeat (2) @(negedge clkb);
        $finish(0);
    end

    // Safety timeout
    initial begin
        repeat (SIM_CYCLES) @(negedge clkb);
        $display("[%0t] TB timeout after %0d cycles", $time, SIM_CYCLES);
        $finish(0);
    end

endmodule
