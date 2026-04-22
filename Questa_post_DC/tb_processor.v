`include "defines.vh"

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

    localparam SIM_CYCLES    = 4000;
    localparam EXEC_CHECK_AT = 1000;

    // Non-overlapping two-phase clock: 20 ns period (50 MHz)
    //   t+0  : dead zone (both low)
    //   t+2  : clka rises
    //   t+7  : clka falls  (negedge clka)
    //   t+10 : clkb rises
    //   t+15 : clkb falls  (negedge clkb)
    //   t+17 : dead zone start, next period at t+20
    initial begin clka = 0; clkb = 0; end
    always begin
        #50  clka = 1;
        #50  clka = 0;
        #50  clkb = 1;
        #50  clkb = 0;
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
            // Gate-level debug mux path is deeper than RTL; allow extra settle time.
            #10;
            data = dbg_data;
        end
    endtask

    // Load one instruction word on the serial interface
    task load_word;
        input [15:0] word;
        begin
            // Gate-level netlists are sensitive to race/timing around active edges.
            // Drive loader inputs on clkb posedge so they are stable before clkb negedge write.
            @(posedge clkb);
            instr_data  = word;
            instr_valid = 1'b1;
            @(posedge clkb);
            instr_valid = 1'b0;
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

        //        PC  Instruction                          Interpretation
        load_word({`ADDI, 3'd1, 3'd0, 6'd5});        //  0  R1 = 5
        load_word({`ADDI, 3'd2, 3'd0, 6'd3});        //  1  R2 = 3
        load_word({`ADD,  3'd3, 3'd1, 3'd2, 3'b000});//  2  R3 = R1+R2 = 8
        load_word({`ST,   3'd0, 3'd3, 6'd0});        //  3  MEM[0] = R3
        load_word({`ADDI, 3'd4, 3'd0, 6'd0});        //  4  R4 = 0
        load_word({`LD,   3'd5, 3'd4, 6'd0});        //  5  R5 = MEM[0] (expect 8)
        load_word({`ADDI, 3'd1, 3'd1, 6'h3F});       //  6  R1 = R1-1 (loop body)
        load_word({`BNEZ, 3'd1, 3'd0, 6'b111110});   //  7  if R1!=0 goto PC 6
        load_word({`JAL,  3'd0, 9'b111111111});       //  8  JAL to self (infinite)
        load_word({`NOP,  12'h000});                  //  9  (unreachable)
        load_word({`HALT, 12'h000});                  // 10
        load_word({`HALT, 12'h000});                  // 11
        load_word({`HALT, 12'h000});                  // 12
        load_word({`HALT, 12'h000});                  // 13
        load_word({`HALT, 12'h000});                  // 14
        load_word({`HALT, 12'h000});                  // 15

        load_done   = 1'b1;
        @(negedge clkb);
        load_done = 1'b0;
        repeat (2) @(negedge clkb);

        // Verify IMEM contents through debug port (addresses 0x10-0x1F)
        $display("");
        $display("===== IMEM Verification (via debug port) =====");
        dbg_read(7'h10, dbg_tmp); check16("IMEM[00]", dbg_tmp, {`ADDI, 3'd1, 3'd0, 6'd5});
        dbg_read(7'h11, dbg_tmp); check16("IMEM[01]", dbg_tmp, {`ADDI, 3'd2, 3'd0, 6'd3});
        dbg_read(7'h12, dbg_tmp); check16("IMEM[02]", dbg_tmp, {`ADD,  3'd3, 3'd1, 3'd2, 3'b000});
        dbg_read(7'h13, dbg_tmp); check16("IMEM[03]", dbg_tmp, {`ST,   3'd0, 3'd3, 6'd0});
        dbg_read(7'h14, dbg_tmp); check16("IMEM[04]", dbg_tmp, {`ADDI, 3'd4, 3'd0, 6'd0});
        dbg_read(7'h15, dbg_tmp); check16("IMEM[05]", dbg_tmp, {`LD,   3'd5, 3'd4, 6'd0});
        dbg_read(7'h16, dbg_tmp); check16("IMEM[06]", dbg_tmp, {`ADDI, 3'd1, 3'd1, 6'h3F});
        dbg_read(7'h17, dbg_tmp); check16("IMEM[07]", dbg_tmp, {`BNEZ, 3'd1, 3'd0, 6'b111110});
        dbg_read(7'h18, dbg_tmp); check16("IMEM[08]", dbg_tmp, {`JAL,  3'd0, 9'b111111111});
        dbg_read(7'h19, dbg_tmp); check16("IMEM[09]", dbg_tmp, {`NOP,  12'h000});
        for (i = 10; i < 16; i = i + 1) begin
            dbg_read(7'h10 + i[6:0], dbg_tmp);
            if (dbg_tmp !== {`HALT, 12'h000}) begin
                $display("  FAIL IMEM[%02d] : got 0x%04h, expected HALT", i, dbg_tmp);
                err_count = err_count + 1;
            end else
                $display("  OK   IMEM[%02d] = HALT", i);
        end

        $display("");
        $display("[%0t] Program loaded, execution begins", $time);
    end

    // Post-synthesis netlist is flattened: use only top-level handshake to track execution.
    always @(negedge clkb) begin
        if (!ready)
            exec_cycle = exec_cycle + 1;
    end


// Final state checks: everything read through the debug port
    initial begin
        wait (ready == 1'b0);
        repeat (EXEC_CHECK_AT) @(negedge clkb);

        $display("");
        $display("===== Final State Check (cycle %0d, via debug port) =====", exec_cycle);

        // Register file (debug addresses 0x00-0x07)
        $display("--- Register File ---");
        for (i = 0; i < 8; i = i + 1) begin
            dbg_read(i[6:0], dbg_tmp);
            $display("  R%0d = %6d  (0x%04h)", i, $signed(dbg_tmp), dbg_tmp);
        end

        $display("--- Register Checks ---");
        dbg_read(7'h00, dbg_tmp); check16("R0", dbg_tmp, 16'd0);
        dbg_read(7'h01, dbg_tmp); check16("R1", dbg_tmp, 16'd0);
        dbg_read(7'h02, dbg_tmp); check16("R2", dbg_tmp, 16'd3);
        dbg_read(7'h03, dbg_tmp); check16("R3", dbg_tmp, 16'd8);
        dbg_read(7'h04, dbg_tmp); check16("R4", dbg_tmp, 16'd0);
        dbg_read(7'h05, dbg_tmp); check16("R5", dbg_tmp, 16'd8);
        dbg_read(7'h06, dbg_tmp); check16("R6", dbg_tmp, 16'd0);
        dbg_read(7'h07, dbg_tmp); check16("R7", dbg_tmp, 16'd0);

        // Data cache: ST wrote 8 to address 0.
        // addr 0 -> cache index 0, word offset 0, tag 0.
        // Cache data line 0 word 0 is at debug address 0x40.
        $display("--- Data Cache (via debug port) ---");
        dbg_read(7'h40, dbg_tmp); check16("cache[0] word0", dbg_tmp, 16'd8);

        // Cache metadata line 0 at debug address 0x50: expect valid=1, dirty=1, tag=0
        dbg_read(7'h50, dbg_tmp);
        $display("  META[0] = 0x%04h  (valid=%b dirty=%b tag=%b)",
                 dbg_tmp, dbg_tmp[2], dbg_tmp[1], dbg_tmp[0]);
        check16("META[0]", dbg_tmp, {13'b0, 1'b1, 1'b1, 1'b0});

        // DMEM[0] via debug address 0x20: should still be 0 because cache is dirty
        // (write-back has not flushed yet)
        dbg_read(7'h20, dbg_tmp);
        $display("  DMEM[0] = %0d (0x%04h) (backing store, not yet written back)", $signed(dbg_tmp), dbg_tmp);

        // PC via debug address 0x58
        $display("--- Pipeline ---");
        dbg_read(7'h58, dbg_tmp);
        $display("  PC (debug) = %0d", dbg_tmp);
        $display("  halted     = %b  (expected 0: HALT unreachable past JAL loop)", halted);

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
