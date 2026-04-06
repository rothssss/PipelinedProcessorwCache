// Small directed test: dual-phase clocks (clka/clkb from opposite clk). Ends after SIM_CYCLES.

`timescale 1ns / 1ps

module tb_processor;

    reg        clk;
    reg        reset_pi;
    wire       clka;
    wire       clkb;
    localparam SIM_CYCLES = 400;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    assign clka = clk;
    assign clkb = ~clk;

    processor dut (
        .clka(clka),
        .clkb(clkb),
        .reset_pi(reset_pi)
    );

    initial begin
        reset_pi = 1'b1;
        repeat (3) @(negedge clkb);
        reset_pi = 1'b0;
    end

    initial begin
        wait (reset_pi === 1'b0);
        repeat (SIM_CYCLES) @(negedge clkb);
        $display("TB finished after %0d cycles", SIM_CYCLES);
        $finish(0);
    end

endmodule
