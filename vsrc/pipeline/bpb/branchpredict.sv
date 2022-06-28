`ifndef __BRANCHPREDICT_SV
`define __BRANCHPREDICT_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/bpb/TwoBitCounter.sv"
`else

`endif

module branchpredict
	import common::*;
    import pipes::*;
    import decode_pkg::*;#(
    parameter BPB_ENTRY_WIDTH = 8,
    BPB_ENTRY_LINE = 256
)(
    input logic clk, reset, en, 
    input branchorjump_t commit_instr_bj,
    input u32 raw_instr,
    input bp_result_t instr_fetch, instr_commit,
    output bp_result_t bp_result
    );

    logic is_branch, bplinew_en, is_jal;
    pcsrc_t bp_pcsrc, predict_pcsrc;
    logic [BPB_ENTRY_WIDTH - 1: 0] entry, entry_commit;
    addr_t pcplus4, predict_pc, pc_jump;

    assign entry = instr_fetch.pc[BPB_ENTRY_WIDTH + 1: 2];
    assign entry_commit = instr_commit.pc[BPB_ENTRY_WIDTH + 1: 2];
    assign pcplus4 = instr_fetch.pc + 64'b100;

    always_comb begin
        is_jal = 0;
        is_branch = 0;
        pc_jump = pcplus4;
        unique case (raw_instr[6:0]) 
            OP_JAL: begin
                is_jal = 1;
                pc_jump = instr_fetch.pc + {{44{raw_instr[31]}}, raw_instr[19:12], raw_instr[20:20], raw_instr[30:21], 1'b0};
            end 
            OP_BEQ: begin
                is_branch = 1;
                pc_jump = instr_fetch.pc + {{52{raw_instr[31]}}, raw_instr[7:7], raw_instr[30:25], raw_instr[11:8], 1'b0};
            end 
            default: begin
                // remains 0, pcplus4
            end
        endcase
    end
    // jal instr should not have an influnce on 2bit-counter
    assign bplinew_en = commit_instr_bj == B_BEQ;// & ~is_jal, implemented in core.sv, module port
    pcsrc_t predict_pcsrc_set[BPB_ENTRY_LINE - 1: 0];
    genvar j;
    generate 
        for (j = 0; j < BPB_ENTRY_LINE; j = j + 1) begin
            TwoBitCounter TwoBitCounter(
                .clk, .reset, .en, 
                .wen(bplinew_en && entry_commit == j), // donot forget entry_commit == j!!!
                .is_taken(instr_commit.pcsrc == PCJUMP),
                .bp_pcsrc(predict_pcsrc_set[j])
            );
        end
    endgenerate

    always_comb begin
        predict_pcsrc = is_jal ? PCJUMP : 
                            is_branch ? predict_pcsrc_set[entry] :
                            PCPLUS4;
        predict_pc = predict_pcsrc == PCJUMP ? pc_jump : pcplus4;
    end
    assign bp_result.pc = instr_fetch.pc;
    assign bp_result.target_pc = predict_pc;
    assign bp_result.pcsrc = predict_pcsrc;
    
endmodule
`endif 