`ifndef __ALU_SV
`define __ALU_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/decode/decode_pkg.sv"
`else

`endif

module alu
	import common::*;
	import pipes::*;
	import decode_pkg::*;(
	input u64 a, b,
	input alufunc_t alufunc,
	input logic is_32instr,
	output u64 c
);

	u64 cout;
	always_comb begin
		cout = '0;
		unique case(alufunc)
			ALU_ADD: cout = a + b;
			ALU_SUB: cout = a - b;
			ALU_AND: cout = a & b;
			ALU_OR:  cout = a | b;
			ALU_XOR: cout = a ^ b;
			ALU_SLL: cout = a << b[5:0];
			ALU_SLLW: cout = a << b[4:0];
			ALU_SRA: cout = $signed(a) >>> b[5:0];
			ALU_SRL: cout = a >> b[5:0];
			ALU_SRAW: cout[31:0] = $signed(a[31:0]) >>> b[4:0];
			ALU_SRLW: cout[31:0] = a[31:0] >> b[4:0];
			ALU_SLT: cout = $signed(a) < $signed(b) ? 64'b1 : 64'b0;
			ALU_SLTU: cout = a < b ? 64'b1 : 64'b0;
			ALU_CSR: cout = a;
			default: begin
				cout = '0;
			end
		endcase
	end
	// for 32bit-data instr
	assign c = is_32instr ? {{32{cout[31]}}, cout[31:0]} : cout;	
	
endmodule

`endif
