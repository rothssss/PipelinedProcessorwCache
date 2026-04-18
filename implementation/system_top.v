// FSM for loading program and run, with debug read-back port.
//
// To load the program to run properly,
//   reset_pi high for 1 or more cycle.
//   reset_pi = 0.  System enters S_LOAD (ready_po = 1).
//   For each instruction word: drive instr_data_pi, pulse instr_valid_pi for 1 cycle.
//   After the last word, pulse load_done_pi for 1 cycle.
//   System enters S_RUN.  Processor reset is released on the next clkb negedge.
//
// Debug read-back: drive dbg_addr_pi, read dbg_data_po (combinational).
//   0x00-0x07  Register file R0-R7
//   0x10-0x1F  IMEM[0..15]
//   0x20-0x3F  DMEM[0..31]
//   0x40-0x4F  Cache data (line[3:2], word[1:0])
//   0x50-0x53  Cache metadata {13'b0, valid, dirty, tag}
//   0x58       PC (zero-extended)

module system_top (
    input  wire        clka,
    input  wire        clkb,
    input  wire        reset_pi,
    input  wire [15:0] instr_data_pi,
    input  wire        instr_valid_pi,
    input  wire        load_done_pi,
    output wire        halted_po,
    output wire        ready_po,
    input  wire [6:0]  dbg_addr_pi,
    output reg  [15:0] dbg_data_po
);

    localparam S_LOAD = 1'b0;
    localparam S_RUN  = 1'b1;

    reg       state;
    reg [3:0] wr_addr;

    // Processor signals
    wire [3:0]  proc_pc;
    wire [15:0] imem_instruction;

    wire imem_we    = (state == S_LOAD) && instr_valid_pi;
    wire proc_reset = reset_pi | (state != S_RUN);

    // Debug sub-addresses routed to each module
    wire [2:0] dbg_rf_addr   = dbg_addr_pi[2:0];
    wire [3:0] dbg_imem_addr = dbg_addr_pi[3:0];

    // Map 7bit debug address input to data_mem_cached 6-bit address space
    reg [5:0] dbg_mem_addr;
    always @(*) begin
        if (dbg_addr_pi[6:5] == 2'b01)
            dbg_mem_addr = {1'b0, dbg_addr_pi[4:0]};
        else if (dbg_addr_pi[6:4] == 3'b100)
            dbg_mem_addr = {2'b10, dbg_addr_pi[3:0]};
        else
            dbg_mem_addr = {4'b1100, dbg_addr_pi[1:0]};
    end

    // Debug data from each sub-module
    wire [15:0] dbg_rf_data;
    wire [15:0] dbg_imem_data;
    wire [15:0] dbg_mem_data;
    wire [3:0]  dbg_pc;

    instruction_mem imem (
        .clkb            (clkb),
        .imem_addr_pi    (proc_pc),
        .instruction_po  (imem_instruction),
        .imem_we_pi      (imem_we),
        .imem_waddr_pi   (wr_addr),
        .imem_wdata_pi   (instr_data_pi),
        .dbg_addr_pi     (dbg_imem_addr),
        .dbg_data_po     (dbg_imem_data)
    );

    processor proc (
        .clka            (clka),
        .clkb            (clkb),
        .reset_pi        (proc_reset),
        .if_instr_pi     (imem_instruction),
        .pc_fetch_po     (proc_pc),
        .halted_po       (halted_po),
        .dbg_rf_addr_pi  (dbg_rf_addr),
        .dbg_rf_data_po  (dbg_rf_data),
        .dbg_mem_addr_pi (dbg_mem_addr),
        .dbg_mem_data_po (dbg_mem_data),
        .dbg_pc_po       (dbg_pc)
    );

    // Loader FSM
    always @(negedge clkb) begin
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

    // Debug output MUX (purely combinational)
    always @(*) begin
        dbg_data_po = 16'b0;
        if (dbg_addr_pi < 7'h08)
            dbg_data_po = dbg_rf_data;
        else if (dbg_addr_pi >= 7'h10 && dbg_addr_pi <= 7'h1F)
            dbg_data_po = dbg_imem_data;
        else if (dbg_addr_pi >= 7'h20 && dbg_addr_pi <= 7'h53)
            dbg_data_po = dbg_mem_data;
        else if (dbg_addr_pi == 7'h58)
            dbg_data_po = {12'b0, dbg_pc};
    end

endmodule
