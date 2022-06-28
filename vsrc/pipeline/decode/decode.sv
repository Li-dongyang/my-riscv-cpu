`ifndef __DECODER_SV
`define __DECODE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/decode/decoder.sv"
`include "pipeline/decode/change_pcsrc.sv"
`else

`endif

module decode
	import common::*;
    import pipes::*;(
    // PIPELINE
	input fetch_data_t dataF,
    output decode_data_t dataD,
    output instr_t dataD_instr,
    // check branchpredict hit
    output bp_result_t instr_commit,
    output logic bp_hit,
    // regfile
    output regfile_i_t regfile_i,
    input regfile_o_t regfile_o,
    // bypass
    input forward_t forward
);
    
    instr_t instr;
    u32 raw_instr;
    csr_ctl_t csr_ctl, csr_ctl0;
    word_t rd1, rd2;

    decoder decoder(
        .raw_instr,
        .instr, .csr_ctl
    );
    // check branch&jump instr jump or not, then change pcsrc, return it to bpb;
    change_pcsrc changePcsrc(.pc_o(dataF.pc_o), .instr,
            .rd1, .rd2,
            .instr_commit, .predict_pcsrc(dataF.predict_pcsrc),
            .bp_hit
            );

    // regfile input 
    assign regfile_i.ra1 = instr.ra1;
    assign regfile_i.ra2 = instr.ra2;

    // exception_
    assign raw_instr = dataF.pc_o[1:0] == 0 ? dataF.raw_instr : '0;
    always_comb begin
        csr_ctl0 = '0;
        if(dataF.pc_o[1:0] != 0) begin // missalign
            csr_ctl0.is_except = 1'b1;
            csr_ctl0.except_name = E_INSTR_MISALIGN;
        end else if(instr.op == 0 && raw_instr != 0 && raw_instr != 32'h5006b) begin // illegal instr
            csr_ctl0.is_except = 1'b1;
            csr_ctl0.except_name = E_INSTR_ILLEGAL;
        end else begin
            csr_ctl0 = csr_ctl;    
        end
    end

    //regdata and forward
    always_comb begin : fad
        unique case(forward.forwardAD)
            FORWARDM: 
                rd1 = forward.dataE_o.aluout;
            FORWARDM1:
                rd1 = forward.dataM1.aluout;
            FORWARDW: 
                rd1 = forward.dataW.write_data;
            default: 
                rd1 = regfile_o.rd1;
        endcase
        dataD.rd1 = rd1; 
    end 
    always_comb begin : fbd
        unique case(forward.forwardBD)
            FORWARDM: 
                rd2 = forward.dataE_o.aluout;
            FORWARDM1:
                rd2 = forward.dataM1.aluout;
            FORWARDW: 
                rd2 = forward.dataW.write_data;
            default: 
                rd2 = regfile_o.rd2;
        endcase
        dataD.rd2 = rd2;
    end 
    // other data output
    assign dataD.pc_o = dataF.pc_o;
    assign dataD_instr = instr;
    assign dataD.instr = instr;
    assign dataD.pcsrc = instr_commit.pcsrc;
    assign dataD.pc_and_instr = dataF;
    assign dataD.csr_ctl = csr_ctl0;
    
endmodule
`endif 