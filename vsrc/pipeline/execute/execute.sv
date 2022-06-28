`ifndef __EXECUTE_SV
`define __EXECUTE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/decode/decode_pkg.sv"
`include "pipeline/execute/alu.sv"
`include "pipeline/execute/mult/multicycle.sv"
`else

`endif
module execute
	import common::*;
	import pipes::*;
	import decode_pkg::*;(
	input logic clk, reset, flushDE, stalllDE, 
	input decode_data_t dataD,
	input forward_t forward,
	output execute_data_t dataE,
	output logic multicycle_doing
);
	instr_t instr;
	assign instr = dataD.instr;
	control_t ctl;
	assign ctl = dataD.instr.ctl;
	word_t a, b, c, regdatab, multi_c;
	word_t writedata = '0;
	word_t aluresult = '0;

	// assign a = dataD.rd1;
	// forward logic: MUX
	always_comb begin : fae
		unique case (forward.forwardAE)
			FORWARDM:
				a = forward.dataE_o.aluout;
			FORWARDM1:
				a = forward.dataM1.aluout;
			FORWARDW:
				a = forward.dataW.write_data;
			default: 
				a = dataD.rd1;
		endcase
	end
	always_comb begin : fbe
		unique case (forward.forwardBE)
			FORWARDM:
				regdatab = forward.dataE_o.aluout;
			FORWARDM1:
				regdatab = forward.dataM1.aluout;
			FORWARDW:
				regdatab = forward.dataW.write_data;
			default: 
				regdatab = dataD.rd2;
		endcase
	end
	// alusrc 
	assign b = ctl.alusrc == RD2 ? regdatab : instr.imm;

	// alu
	alu alu_inst(
		.a, .b, .alufunc(ctl.aluop),
		.is_32instr(ctl.is_32instr),
		.c
	);
	// multicycle instr like mul, div, rem
	logic doing;
	assign multicycle_doing = doing && (ctl.aluop == ALU_MULTICYCLE);
	multicycle multicycle_inst(
		.clk, .reset, .flushDE, .stalllDE,
		.op(instr.op), .is_32instr(ctl.is_32instr),
		.a, .b,
		.multi_c, .doing
	);

	// dataD.pc_o is used for pc_jump for wire-saving; in dataE we'll correct pc_o back
	// alu especially for branch & jump instr; all B-instr are in B_BEQ, they can't change reg/mem
	addr_t pcplus4;
	always_comb begin : branch_or_jump
		pcplus4 = dataD.pc_and_instr.pc_o + 64'd4;
		dataE.pc_o = dataD.pc_and_instr.pc_o;
		unique case (ctl.bj)
			B_BEQ: begin
				aluresult = c; // the beq donot change aluresult(it cannot change the regfile)
			end
			J_JAL:begin
				aluresult = pcplus4; // jal writeback data
			end
			I_JALR:begin
				aluresult = pcplus4; // jalr writeback data
			end
			U_AUIPC:begin
				aluresult = dataD.pc_and_instr.pc_o + instr.imm; // has already been shifted!
			end
			default: begin
				aluresult = c; 
			end
		endcase
	end
	// other out
	assign dataE.instr = dataD.instr;
	assign dataE.aluout = ctl.aluop == ALU_MULTICYCLE ? multi_c : ctl.bj == NOTHING ? c : aluresult;
	assign dataE.memw_data = regdatab;
	assign dataE.pc_and_instr = dataD.pc_and_instr;
	assign dataE.csr_ctl = dataD.csr_ctl;

endmodule
`endif