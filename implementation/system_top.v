// FSM for loading program and run. 
//
// To load the program to run properly, 
//   reset_pi high for 1 or more cycle.
//   reset_pi = 0.  System enters S_LOAD (ready_po = 1).
//   For each instruction word: drive instr_data_pi, pulse instr_valid_pi for 1 cycle. These will be loaded starting addr 0
//   After the last word, pulse load_done_pi for 1 cycle.
//   System enters S_RUN.  Processor reset is released on the next clkb negedge.

module system_top (
    input  wire        clk,
    input  wire        reset_pi,
    input  wire [15:0] instr_data_pi,
    input  wire        instr_valid_pi,
    input  wire        load_done_pi,
    output wire        halted_po,
    output wire        ready_po
);

    wire clka = clk;
    wire clkb = ~clk;

    localparam S_LOAD = 1'b0;
    localparam S_RUN  = 1'b1;

    reg       state;
    reg [3:0] wr_addr;

    // Processor signals
    wire [3:0]  proc_pc;
    wire [15:0] imem_instruction;

    // IMEM write port driven by the loader
    wire imem_we = (state == S_LOAD) && instr_valid_pi;

    // Processor is held in reset until S_RUN
    wire proc_reset = reset_pi | (state != S_RUN);

    instruction_mem imem (
        .clkb            (clkb),
        .imem_addr_pi    (proc_pc),
        .instruction_po  (imem_instruction),
        .imem_we_pi      (imem_we),
        .imem_waddr_pi   (wr_addr),
        .imem_wdata_pi   (instr_data_pi)
    );

    processor proc (
        .clka         (clka),
        .clkb         (clkb),
        .reset_pi     (proc_reset),
        .if_instr_pi  (imem_instruction),
        .pc_fetch_po  (proc_pc),
        .halted_po    (halted_po)
    );

    // FSM
    // accept words in S_LOAD, processor run in S_RUN
    always @(negedge clkb or posedge reset_pi) begin
        if (reset_pi) begin
            state   <= S_LOAD;
            wr_addr <= 4'd0;
        end else begin
            case (state)
                S_LOAD: begin
                    if (instr_valid_pi)
                        wr_addr <= wr_addr + 4'd1;
                    if (load_done_pi)
                        state <= S_RUN;
                end
                S_RUN: ;
            endcase
        end
    end

    assign ready_po = (state == S_LOAD);

endmodule
