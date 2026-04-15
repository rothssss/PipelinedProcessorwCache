// Testbench: loads the same program that was previously hard-coded in instruction_mem
// through the serial loading interface of system_top, then waits for HALT or timeout.

`timescale 1ns / 1ps

module tb_processor;

    reg        clk;
    reg        reset_pi;
    reg [15:0] instr_data;
    reg        instr_valid;
    reg        load_done;
    wire       halted;
    wire       ready;

    localparam SIM_CYCLES = 400;

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

    task load_word;
        input [15:0] word;
        begin
            instr_data  = word;
            instr_valid = 1'b1;
            @(negedge clk);
        end
    endtask

    initial begin
        reset_pi    = 1'b1;
        instr_data  = 16'b0;
        instr_valid = 1'b0;
        load_done   = 1'b0;

        repeat (3) @(negedge clk);
        reset_pi = 1'b0;
        @(negedge clk);

        // Same program that was previously hard-coded in instruction_mem:
        //   R1=5, R2=3, R3=R1+R2, store R3, load it back,
        //   decrement R1 loop, JAL, NOP, then HALTs.
        load_word({`ADDI, 3'd1, 3'd0, 6'd5});
        load_word({`ADDI, 3'd2, 3'd0, 6'd3});
        load_word({`ADD,  3'd3, 3'd1, 3'd2, 3'b000});
        load_word({`ST,   3'd0, 3'd3, 6'd0});
        load_word({`ADDI, 3'd4, 3'd0, 6'd0});
        load_word({`LD,   3'd5, 3'd4, 6'd0});
        load_word({`ADDI, 3'd1, 3'd1, 6'h3F});
        load_word({`BNEZ, 3'd1, 3'd0, 6'b111110});
        load_word({`JAL,  3'd0, 9'b111111111});
        load_word({`NOP,  12'h000});
        load_word({`HALT, 12'h000});
        load_word({`HALT, 12'h000});
        load_word({`HALT, 12'h000});
        load_word({`HALT, 12'h000});
        load_word({`HALT, 12'h000});
        load_word({`HALT, 12'h000});

        instr_valid = 1'b0;
        load_done   = 1'b1;
        @(negedge clk);
        load_done = 1'b0;

        $display("[%0t] Program loaded — processor starting", $time);
    end

    initial begin
        @(posedge halted);
        repeat (5) @(negedge clk);
        $display("[%0t] TB finished: processor halted", $time);
        $finish(0);
    end

    initial begin
        repeat (SIM_CYCLES) @(negedge clk);
        $display("[%0t] TB timeout after %0d cycles", $time, SIM_CYCLES);
        $finish(0);
    end

endmodule
