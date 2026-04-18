// cache FSM: S0 idle/action, S1 dirty writeback, S2 fetch block, S3 install.
// All sequential logic negedge clkb. addr_pi is word address 0..31 (stack / high data: `defines.vh STACK_BASE).

// req_valid_pi: MEM-stage LD/ST active; stall_po mirrors reference (state!=S0 || miss).

module data_mem_cached (
    input wire clkb,
    input wire reset_pi,
    input wire req_valid_pi,
    input wire req_write_pi,
    input wire [4:0] addr_pi,
    input wire [15:0] wdata_pi,
    output wire [15:0] rdata_po,
    output wire stall_po,
    // Debug read ports, see README debug session. 
    input  wire [5:0]  dbg_addr_pi,
    output reg  [15:0] dbg_data_po
);

    localparam S0 = 2'd0;
    localparam S1 = 2'd1;
    localparam S2 = 2'd2;
    localparam S3 = 2'd3;

    reg [15:0] DMEM [0:31];
    reg [63:0] DATA_ARRAY [0:3];
    reg        TAG_ARRAY   [0:3];
    reg        VALID_ARRAY [0:3];
    reg        DIRTY_ARRAY [0:3];

    reg [1:0] currentState;
    reg [63:0] mem_block_data;

    wire [1:0] cache_index = addr_pi[3:2];
    wire [1:0] word_offset = addr_pi[1:0];
    wire       tag         = addr_pi[4];

    wire valid      = VALID_ARRAY[cache_index];
    wire dirty      = DIRTY_ARRAY[cache_index];
    wire tag_match  = (TAG_ARRAY[cache_index] == tag);
    wire cache_hit  = req_valid_pi && valid && tag_match;
    wire cache_miss = req_valid_pi && (!valid || !tag_match);

    reg [63:0] cache_block_data;
    reg [63:0] wb_data;
    reg [15:0] load_data;

    reg [1:0] nextState;

    assign stall_po = req_valid_pi && ((currentState != S0) || cache_miss);
    assign rdata_po = load_data;

    always @(*) begin
        load_data = 16'b0;
        if (currentState == S0 && cache_hit && req_valid_pi && !req_write_pi) begin
            cache_block_data = DATA_ARRAY[cache_index];
            case (word_offset)
                2'd0: load_data = cache_block_data[15:0];
                2'd1: load_data = cache_block_data[31:16];
                2'd2: load_data = cache_block_data[47:32];
                2'd3: load_data = cache_block_data[63:48];
            endcase
        end
    end

    always @(*) begin
        nextState = currentState;
        case (currentState)
            S0: begin
                if (cache_miss) begin
                    if (dirty && valid)
                        nextState = S1;
                    else
                        nextState = S2;
                end
            end
            S1: nextState = S2;
            S2: nextState = S3;
            S3: nextState = S0;
            default: nextState = S0;
        endcase
    end

    integer wi, bidx;
    always @(negedge clkb or posedge reset_pi) begin
        if (reset_pi) begin
            currentState <= S0;
            for (wi = 0; wi < 32; wi = wi + 1)
                DMEM[wi] <= 16'b0;
            for (wi = 0; wi < 4; wi = wi + 1) begin
                DATA_ARRAY[wi] <= 64'b0;
                VALID_ARRAY[wi] <= 1'b0;
                DIRTY_ARRAY[wi] <= 1'b0;
                TAG_ARRAY[wi] <= 1'b0;
            end
        end else begin
            case (currentState)
                S0: begin
                    if (cache_hit && req_valid_pi && req_write_pi) begin
                        cache_block_data = DATA_ARRAY[cache_index];
                        case (word_offset)
                            2'd0: cache_block_data[15:0]   = wdata_pi;
                            2'd1: cache_block_data[31:16]  = wdata_pi;
                            2'd2: cache_block_data[47:32]  = wdata_pi;
                            2'd3: cache_block_data[63:48] = wdata_pi;
                        endcase
                        DATA_ARRAY[cache_index] <= cache_block_data;
                        DIRTY_ARRAY[cache_index] <= 1'b1;
                    end
                end
                S1: begin
                    wb_data = DATA_ARRAY[cache_index];
                    bidx = {TAG_ARRAY[cache_index], cache_index, 2'b00};
                    DMEM[bidx + 0] <= wb_data[15:0];
                    DMEM[bidx + 1] <= wb_data[31:16];
                    DMEM[bidx + 2] <= wb_data[47:32];
                    DMEM[bidx + 3] <= wb_data[63:48];
                end
                S2: begin
                    bidx = {tag, cache_index, 2'b00};
                    mem_block_data <= {DMEM[bidx + 3], DMEM[bidx + 2],
                                       DMEM[bidx + 1], DMEM[bidx + 0]};
                end
                S3: begin
                    DATA_ARRAY[cache_index] <= mem_block_data;
                    TAG_ARRAY[cache_index]  <= tag;
                    VALID_ARRAY[cache_index] <= 1'b1;
                    DIRTY_ARRAY[cache_index] <= 1'b0;
                end
                default: ;
            endcase
            currentState <= nextState;
        end
    end

    // Debug read mux
    reg [63:0] dbg_cache_block;
    always @(*) begin
        dbg_data_po = 16'b0;
        dbg_cache_block = 64'b0;
        if (dbg_addr_pi < 6'd32) begin
            dbg_data_po = DMEM[dbg_addr_pi[4:0]];
        end else if (dbg_addr_pi < 6'd48) begin
            dbg_cache_block = DATA_ARRAY[dbg_addr_pi[3:2]];
            case (dbg_addr_pi[1:0])
                2'd0: dbg_data_po = dbg_cache_block[15:0];
                2'd1: dbg_data_po = dbg_cache_block[31:16];
                2'd2: dbg_data_po = dbg_cache_block[47:32];
                2'd3: dbg_data_po = dbg_cache_block[63:48];
            endcase
        end else if (dbg_addr_pi < 6'd52) begin // this is probing the cache, see cache def. 
            dbg_data_po = {13'b0,
                           VALID_ARRAY[dbg_addr_pi[1:0]],
                           DIRTY_ARRAY[dbg_addr_pi[1:0]],
                           TAG_ARRAY[dbg_addr_pi[1:0]]};
        end
    end

endmodule
