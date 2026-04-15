// clka PC seq, clkb pipeline and regfile write and DMEM 
// Branch / JAL / RET resolved in EX. next_pc MUX: EX targets +1 sequential when no redirect.
// if_instr_pi: fetched instruction word from external IMEM. pc_fetch_po: current PC for IMEM read.

module processor (
    input wire clka,
    input wire clkb,
    input wire reset_pi,
    input  wire [15:0] if_instr_pi,
    output wire [3:0]  pc_fetch_po,
    output wire        halted_po
);

    wire [15:0] if_instr = if_instr_pi;
    wire [3:0]  pc_fetch;

    reg [15:0] if_id_instrM;
    reg [3:0]  if_id_pcM;

    reg [3:0]  id_ex_pcM;
    reg [15:0] id_ex_r1M;
    reg [15:0] id_ex_r2M;
    reg [15:0] id_ex_offM;
    reg [6:0]  id_ex_ctrlM;
    reg        id_ex_shM;
    reg        id_ex_weM;
    reg        id_ex_haltM;
    reg [3:0]  id_ex_opcM;
    reg [2:0]  id_ex_rsM;
    reg [2:0]  id_ex_rtM;
    reg [2:0]  id_ex_rdM;

    reg [15:0] ex_mem_aluM;
    reg [15:0] ex_mem_sdatM;
    reg [6:0]  ex_mem_ctrlM;
    reg        ex_mem_weM;
    reg        ex_mem_haltM;
    reg [3:0]  ex_mem_opcM;
    reg [2:0]  ex_mem_rdM;
    reg        ex_mem_ldM;
    reg        ex_mem_stM;

    reg [15:0] mem_wb_aluM;
    reg [15:0] mem_wb_memM;
    reg        mem_wb_weM;
    reg        mem_wb_haltM;
    reg [3:0]  mem_wb_opcM;
    reg [2:0]  mem_wb_rdM;
    reg        mem_wb_ldM;

    wire [2:0] din_rs;
    wire [2:0] din_rt;
    wire [3:0] dec_opc_unused;
    wire [15:0] din_off;
    wire [6:0] din_ctrl;
    wire [2:0] din_rd;
    wire       din_sh;
    wire       din_we;
    wire       din_halt;

    wire [15:0] rf_wd;
    wire        rf_we;

    assign pc_fetch_po = pc_fetch;

    decode dec (
        .instr_pi(if_id_instrM),
        .opCode_po(dec_opc_unused),
        .rs_po(din_rs),
        .rt_po(din_rt),
        .offset_po(din_off),
        .control_po(din_ctrl),
        .destReg_po(din_rd),
        .shift_modifier_po(din_sh),
        .writeEnable_po(din_we),
        .isHalt_po(din_halt)
    );

    wire [15:0] rf_r1;
    wire [15:0] rf_r2;

    reg_file rf (
        .clkb(clkb),
        .reset_pi(reset_pi),
        .raddr1_pi(din_rs),
        .raddr2_pi(din_rt),
        .waddr_pi(mem_wb_rdM),
        .we_pi(rf_we),
        .wdata_pi(rf_wd),
        .rdata1_po(rf_r1),
        .rdata2_po(rf_r2)
    );

    function uses_rs;
        input [3:0] op;
        begin
            case (op)
                `JAL, `NOP, `HALT: uses_rs = 1'b0;
                default: uses_rs = 1'b1;
            endcase
        end
    endfunction

    function uses_rt;
        input [3:0] op;
        begin
            case (op)
                `ADD, `AND, `XOR, `ST: uses_rt = 1'b1;
                default: uses_rt = 1'b0;
            endcase
        end
    endfunction

    wire [15:0] wb_mux = mem_wb_ldM ? mem_wb_memM : mem_wb_aluM;

    wire [3:0] id_opc_d = if_id_instrM[15:12];

    wire        id_ex_ld = id_ex_ctrlM[2];
    wire        ex_ld    = ex_mem_ldM;
    wire [2:0]  ex_rd    = ex_mem_rdM;
    wire        stall_ld_exmem = ex_ld && (ex_rd != 3'b000) &&
        ((uses_rs(id_ex_opcM) && (ex_rd == id_ex_rsM))
         || (uses_rt(id_ex_opcM) && (ex_rd == id_ex_rtM)));
    wire        stall_ld_idex = id_ex_ld && (id_ex_rdM != 3'b000) &&
        ((uses_rs(id_opc_d) && (id_ex_rdM == din_rs))
         || (uses_rt(id_opc_d) && (id_ex_rdM == din_rt)));
    wire        stall_ld = stall_ld_exmem | stall_ld_idex;

    wire        dmem_req;
    wire        dmem_we;
    wire [4:0]  dmem_addr;
    wire [15:0] dmem_wdata;
    wire [15:0] dmem_rdata;
    wire        dmem_stall;

    data_mem_cached dmem (
        .clkb(clkb),
        .reset_pi(reset_pi),
        .req_valid_pi(dmem_req),
        .req_write_pi(dmem_we),
        .addr_pi(dmem_addr),
        .wdata_pi(dmem_wdata),
        .rdata_po(dmem_rdata),
        .stall_po(dmem_stall)
    );

    assign dmem_req   = ex_mem_ldM | ex_mem_stM;
    assign dmem_we    = ex_mem_stM;
    assign dmem_addr  = ex_mem_aluM[4:0];
    assign dmem_wdata = ex_mem_sdatM;

    wire stall_total = stall_ld | dmem_stall;

    wire       id_ex_j  = id_ex_ctrlM[6];
    wire       id_ex_r  = id_ex_ctrlM[5];
    wire       id_ex_b  = id_ex_ctrlM[4];

    wire [15:0] op1_fw;
    wire [15:0] op2_fw;

    wire fwd_ex_rs = (ex_mem_rdM != 3'b000) && !ex_mem_ldM
        && (ex_mem_rdM == id_ex_rsM) && uses_rs(id_ex_opcM);
    wire fwd_wb_rs = (mem_wb_rdM != 3'b000) && (mem_wb_rdM == id_ex_rsM) && uses_rs(id_ex_opcM);
    wire fwd_ex_rt = (ex_mem_rdM != 3'b000) && !ex_mem_ldM
        && (ex_mem_rdM == id_ex_rtM) && uses_rt(id_ex_opcM);
    wire fwd_wb_rt = (mem_wb_rdM != 3'b000) && (mem_wb_rdM == id_ex_rtM) && uses_rt(id_ex_opcM);

    assign op1_fw = fwd_ex_rs ? ex_mem_aluM : (fwd_wb_rs ? wb_mux : id_ex_r1M);
    assign op2_fw = fwd_ex_rt ? ex_mem_aluM : (fwd_wb_rt ? wb_mux : id_ex_r2M);

    wire [15:0] op2_alu  = (id_ex_opcM == `NOT) ? 16'b0 : op2_fw;
    wire [15:0] alu_res_raw;
    wire        br_cond;

    alu aluu (
        .op1_pi(op1_fw),
        .op2_pi(op2_alu),
        .aluFunc_pi(id_ex_opcM),
        .offset_pi(id_ex_offM),
        .shift_modifier_pi(id_ex_shM),
        .result_po(alu_res_raw),
        .branchCond_po(br_cond)
    );

    wire        br_taken  = id_ex_b & br_cond;
    wire        take_flow = br_taken | id_ex_j | id_ex_r;
    wire [15:0] pc_ext    = {12'b0, id_ex_pcM};
    wire [15:0] flow_add  = pc_ext + 16'd1 + id_ex_offM;
    wire [3:0]  flow_pc   = id_ex_r ? op1_fw[3:0] : flow_add[3:0];

    wire flush = take_flow & ~stall_total;

    wire        halt_cpu = (if_id_instrM[15:12] == `HALT);

    reg [3:0] pc_reg;
    reg [3:0] pc_out;

    assign pc_fetch = pc_out;

    // next_pc_sel: redirect on EX-stage control flow (branch/JAL/RET) else sequential word PC+1.
    wire [3:0] next_pc_sel = take_flow & ~stall_total ? flow_pc : (pc_reg + 4'd1);

    always @(negedge clka or posedge reset_pi) begin
        if (reset_pi)
            pc_reg <= 4'b0;
        else if (~halt_cpu & ~stall_total)
            pc_reg <= next_pc_sel;
    end

    always @(negedge clkb or posedge reset_pi) begin
        if (reset_pi)
            pc_out <= 4'b0;
        else
            pc_out <= pc_reg;
    end

    wire [15:0] jal_link = pc_ext + 16'd1;
    wire [15:0] alu_fin  = id_ex_j ? jal_link : alu_res_raw;

    always @(negedge clkb or posedge reset_pi) begin
        if (reset_pi) begin
            if_id_instrM  <= 16'b0;
            if_id_pcM     <= 4'b0;
            id_ex_pcM     <= 4'b0;
            id_ex_r1M     <= 16'b0;
            id_ex_r2M     <= 16'b0;
            id_ex_offM    <= 16'b0;
            id_ex_ctrlM   <= 7'b0;
            id_ex_shM     <= 1'b0;
            id_ex_weM     <= 1'b0;
            id_ex_haltM   <= 1'b0;
            id_ex_opcM    <= 4'b0;
            id_ex_rsM     <= 3'b0;
            id_ex_rtM     <= 3'b0;
            id_ex_rdM     <= 3'b0;
            ex_mem_aluM   <= 16'b0;
            ex_mem_sdatM  <= 16'b0;
            ex_mem_ctrlM  <= 7'b0;
            ex_mem_weM    <= 1'b0;
            ex_mem_haltM  <= 1'b0;
            ex_mem_opcM   <= 4'b0;
            ex_mem_rdM    <= 3'b0;
            ex_mem_ldM    <= 1'b0;
            ex_mem_stM    <= 1'b0;
            mem_wb_aluM   <= 16'b0;
            mem_wb_memM   <= 16'b0;
            mem_wb_weM    <= 1'b0;
            mem_wb_haltM  <= 1'b0;
            mem_wb_opcM   <= 4'b0;
            mem_wb_rdM    <= 3'b0;
            mem_wb_ldM    <= 1'b0;
        end else if (~stall_total) begin
            if (flush) begin
                if_id_instrM <= 16'b0;
                if_id_pcM    <= 4'b0;
            end else begin
                if_id_instrM <= if_instr;
                if_id_pcM    <= pc_fetch;
            end
            if (flush) begin
                id_ex_pcM   <= 4'b0;
                id_ex_r1M   <= 16'b0;
                id_ex_r2M   <= 16'b0;
                id_ex_offM  <= 16'b0;
                id_ex_ctrlM <= 7'b0;
                id_ex_shM   <= 1'b0;
                id_ex_weM   <= 1'b0;
                id_ex_haltM <= 1'b0;
                id_ex_opcM  <= 4'b0;
                id_ex_rsM   <= 3'b0;
                id_ex_rtM   <= 3'b0;
                id_ex_rdM   <= 3'b0;
            end else begin
                id_ex_pcM   <= if_id_pcM;
                id_ex_r1M   <= rf_r1;
                id_ex_r2M   <= rf_r2;
                id_ex_offM  <= din_off;
                id_ex_ctrlM <= din_ctrl;
                id_ex_shM   <= din_sh;
                id_ex_weM   <= din_we;
                id_ex_haltM <= din_halt;
                id_ex_opcM  <= id_opc_d;
                id_ex_rsM   <= din_rs;
                id_ex_rtM   <= din_rt;
                id_ex_rdM   <= din_rd;
            end
            ex_mem_aluM  <= alu_fin;
            ex_mem_sdatM <= op2_fw;
            ex_mem_ctrlM <= id_ex_ctrlM;
            ex_mem_weM   <= id_ex_weM;
            ex_mem_haltM <= id_ex_haltM;
            ex_mem_opcM  <= id_ex_opcM;
            ex_mem_rdM   <= id_ex_rdM;
            ex_mem_ldM   <= id_ex_ctrlM[2];
            ex_mem_stM   <= id_ex_ctrlM[3];
            mem_wb_aluM  <= ex_mem_aluM;
            mem_wb_memM  <= dmem_rdata;
            mem_wb_weM   <= ex_mem_weM;
            mem_wb_haltM <= ex_mem_haltM;
            mem_wb_opcM  <= ex_mem_opcM;
            mem_wb_rdM   <= ex_mem_rdM;
            mem_wb_ldM   <= ex_mem_ldM;
        end
    end

    assign rf_wd = wb_mux;
    assign rf_we = mem_wb_weM & ~mem_wb_haltM;
    assign halted_po = halt_cpu;

endmodule
