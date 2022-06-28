`ifndef __CHANGE_PCSRC_SV
`define __CHANGE_PCSRC_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/decode/decode_pkg.sv"
`else

`endif

module change_pcsrc 
    import common::*;
    import pipes::*;
    import decode_pkg::*;(
    input addr_t pc_o,
    input instr_t instr,
    input word_t rd1, rd2,
    output bp_result_t instr_commit,
    input pcsrc_t predict_pcsrc,
    output logic bp_hit
);
    pcsrc_t pcsrc;

    always_comb begin 
        unique case (instr.op)
            JAL: pcsrc = PCJUMP;
            JALR: pcsrc = PCJUMP;
            BEQ: pcsrc = rd1 != rd2 ? PCPLUS4: PCJUMP;
            BNE: pcsrc = rd1 != rd2 ? PCJUMP: PCPLUS4;
            BLT: pcsrc = $signed(rd1) < $signed(rd2) ? PCJUMP: PCPLUS4;
            BLTU: pcsrc = rd1 < rd2 ? PCJUMP: PCPLUS4;
            BGEU: pcsrc = rd1 >= rd2 ? PCJUMP: PCPLUS4;
            BGE: pcsrc = $signed(rd1) >= $signed(rd2) ? PCJUMP: PCPLUS4;
            default: begin
                pcsrc = PCPLUS4;
            end
        endcase
    end

    assign instr_commit.pcsrc = pcsrc;
    assign instr_commit.pc = pc_o;
    assign bp_hit = predict_pcsrc == pcsrc;
    assign instr_commit.target_pc = pcsrc == PCPLUS4 ? pc_o + 64'b100 :
                                    instr.op != JALR ? pc_o + instr.imm : (rd1 + instr.imm); // & (~64'b1), commen it for lab4
    // assign instr_commit.target_pc = instr.op != JALR ?
    //         pc_o + instr.imm : (rd1 + instr.imm) & (~64'b1);
endmodule

`endif 