`ifndef __FETCH_SV
`define __FETCH_SV

`define NO_BP_HIT_RATE

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/fetch/pcselect.sv"
`include "pipeline/bpb/branchpredict.sv"
`else

`endif

module fetch 
	import common::*;
    import pipes::*;(
	input logic clk, reset,
	output ibus_req_t  ireq,
	input  ibus_resp_t iresp,
    // pipeline
    output fetch_data_t dataF,
    // control
    input logic fetch_en, bp_hit,
    input bp_result_t instr_commit,
    input pchold_t pc_hold,
    input csr_pc_nxt_t csr_pc_nxt,
    input branchorjump_t commit_instr_bj
);
    addr_t pc = PCINIT;
    addr_t pc_o, pc_jump_tar, predict_pc;
    logic icache_req_o, i_data_ok;
    u32 raw_instr, dataF_raw_instr;
    pcsrc_t predict_pcsrc;
    
    assign dataF.pc_o = pc;
    // bp_hit means bp is right, we needn't flush anything
    assign pc_jump_tar = bp_hit ? bp_result.target_pc : instr_commit.target_pc;
    assign predict_pcsrc = bp_hit ? bp_result.pcsrc : instr_commit.pcsrc;
    
    pcselect pcselect (
        .reset,
        .pc,
        .pc_o,
        .pcsrc(predict_pcsrc),
        .pc_hold,
        .pc_jump(pc_jump_tar),
        .csr_pc_nxt
    );

    bp_result_t instr_fetch, bp_result;
    assign instr_fetch.pc = pc;
    assign instr_fetch.pcsrc = PCPLUS4;// makes no sense but we must give this port a value
    assign instr_fetch.target_pc = PCINIT;// makes no sense but we must give this port a value
    branchpredict branchpredict(
        .clk, .reset, .en(pc_hold == PCEN), .commit_instr_bj,
        .raw_instr(dataF_raw_instr), .instr_fetch, .instr_commit,
        .bp_result
    );

    always_ff @(posedge clk, posedge reset) begin 
        if(reset) 
            pc <= PCINIT;
        else 
            pc <= pc_o;
    end

    // AXI handshake bus reference: https://zipcpu.com/blog/2021/08/28/axi-rules.html
    assign i_data_ok = iresp.data_ok | ~ireq.valid;
    always_ff @(posedge clk) begin 
        if(reset | csr_pc_nxt.csr_pc_valid)
            icache_req_o <= '1;
        else if(i_data_ok)
            icache_req_o <= fetch_en;
        else
            icache_req_o <= icache_req_o;
    end
    always_ff @(posedge clk) begin 
        if(reset)
            raw_instr <= '0;
        else if(iresp.data_ok) // using the feature that iresp.data_ok keep 1 only one cycle
                raw_instr <= iresp.data;
        else
            raw_instr <= raw_instr;
    end

    // fetch: in and out
    // 1'b1 means we always *want* to fetch instr, but sometimes there's no need
    assign ireq.valid = icache_req_o & ~csr_pc_nxt.csr_pc_valid;//1'b1 & fetch_en;
    assign ireq.addr = pc;
    // raw_instr'll be late for 1 cycle, using iresp.data to avoid this
    assign dataF_raw_instr = iresp.data_ok ? iresp.data : raw_instr;
    assign dataF.raw_instr = dataF_raw_instr; // prevent combinational logic ring (dataF)
    assign dataF.predict_pcsrc = bp_result.pcsrc;

`ifdef BP_HIT_RATE
    u64 all_b; // count the num of branch instr
    u64 hit_cnt; // count hit 
    always_ff @(posedge clk, posedge reset) begin : counter
        if(reset) begin
            {all_b, hit_cnt} <= '0;
        end else begin
            if(pc_hold == PCEN && commit_instr_bj == B_BEQ) begin
                all_b <= all_b + 1;
                if(bp_hit)
                    hit_cnt <= hit_cnt + 1;
            end
            // raw_instr==0x5006b means the whole simulation is over
            if(dataF_raw_instr == 32'h5006b) begin
                $display("|||||||||\n|||||||||\nhit_cnt:%d all branch cnt:%d",
                 hit_cnt, all_b);
            end
        end
    end
`endif 

endmodule
`endif 