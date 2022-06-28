`ifndef __CSR_SV
`define __CSR_SV


`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/decode/decode_pkg.sv"
`include "pipeline/csr/csr_pkg.sv"
// `include "pipeline/execute/mult/multicycle.sv"
`else

`endif

module csr
	import common::*;
	import pipes::*;
	import decode_pkg::*;
	import csr_pkg::*;(
	input logic clk, reset,
	input memory_data_t dataM,
	input logic swint, trint, exint,
	input csr_ctl_t csr_ctl,
	output csr_write_to_reg_t csr_write_to_reg,
	output csr_pc_nxt_t csr_pc_nxt,
	output csr_regs_t regs_nxt,
	output u2 mode_nxt
);
	csr_regs_t regs;
	u64 rd, wd, src1;
	
	addr_t pcplus4, pc_stored, pc_w;
	assign pc_w = dataM.pc_and_instr.pc_o;
	assign pcplus4 = pc_stored + 64'b100;
	assign src1 = dataM.aluout;

	logic csr_wen, is_interupt, is_trint, is_swint, exc_or_int;
	assign is_swint = regs.mstatus.mie & swint & regs.mie[3] & (|pc_w);
	assign is_trint = regs.mstatus.mie & trint & regs.mie[7] & (|pc_w);;
	assign is_interupt = (is_swint | is_trint);
	assign csr_wen = csr_ctl.csr_wen & ~csr_ctl.is_except & ~csr_ctl.is_mret & ~is_interupt;
	// exception or interuption
	assign exc_or_int = csr_ctl.is_except | is_interupt;
	
	
	// decode and execute
	always_comb begin
		unique case (dataM.instr.op)
			CSRRC: begin
				csr_write_to_reg.csr_write_to_reg_en = '1;
				csr_write_to_reg.csr_write_to_reg_data = rd;
				wd = rd & ~src1;
			end
			CSRRCI: begin
				csr_write_to_reg.csr_write_to_reg_en = '1;
				csr_write_to_reg.csr_write_to_reg_data = rd;
				wd = rd & ~({59'b0, csr_ctl.zimm});
			end
			CSRRS: begin
				csr_write_to_reg.csr_write_to_reg_en = '1;
				csr_write_to_reg.csr_write_to_reg_data = rd;
				wd = rd | src1;
			end
			CSRRSI: begin
				csr_write_to_reg.csr_write_to_reg_en = '1;
				csr_write_to_reg.csr_write_to_reg_data = rd;
				wd = rd | ({59'b0, csr_ctl.zimm});
			end
			CSRRW: begin
				csr_write_to_reg.csr_write_to_reg_en = '1;
				csr_write_to_reg.csr_write_to_reg_data = rd;
				wd = src1;
			end
			CSRRWI: begin
				csr_write_to_reg.csr_write_to_reg_en = '1;
				csr_write_to_reg.csr_write_to_reg_data = rd;
				wd = {59'b0, csr_ctl.zimm};
			end
			default: begin
				{wd, csr_write_to_reg} = '0;
			end
		endcase
	end
	// exception code decoder
	logic[MXLEN-2:0] mcause_name;
	always_comb begin
		unique case (csr_ctl.except_name)
			E_INSTR_MISALIGN: mcause_name = INSTR_MISSALIGN;
			E_INSTR_ILLEGAL: mcause_name = INSTR_ILLEGAL;
			E_LD_MISALIGN: mcause_name = LD_MISSALIGN;
			E_SD_MISALIGN: mcause_name = SD_MISSALIGN;
			E_ECALL: begin
				unique case (mode)
					MACHINE_MODE: mcause_name = ECALL_M;
					SUPERVISOR_MODE: mcause_name = ECALL_S;
					USER_MODE: mcause_name = ECALL_U;
					default: mcause_name = regs.mcause[MXLEN-2:0];
				endcase
			end
			E_NO_EXCEPT: begin
				if(trint) 
					mcause_name = M_TRINT;
				else if(swint)
					mcause_name = M_SWINT;
				else 
					mcause_name = regs.mcause[MXLEN-2:0];
			end
			default: 
				 mcause_name = regs.mcause[MXLEN-2:0];
		endcase
	end
	// read
	always_comb begin
		unique case(csr_ctl.csr_name)
			CSR_MIE: rd = regs.mie;
			CSR_MIP: rd = regs.mip;
			CSR_MTVEC: rd = regs.mtvec;
			CSR_MSTATUS: rd = regs.mstatus;
			CSR_MSCRATCH: rd = regs.mscratch;
			CSR_MEPC: rd = regs.mepc;
			CSR_MCAUSE: rd = regs.mcause;
			CSR_MCYCLE: rd = regs.mcycle;
			CSR_MTVAL: rd = regs.mtval;
			default: begin
				rd = '0;
			end
		endcase
	end

	// write
	always_comb begin
		regs_nxt = regs;
		{regs_nxt.mie[3], regs_nxt.mie[7], regs_nxt.mie[11], regs_nxt.mip[3], regs_nxt.mip[7], regs_nxt.mip[11], regs_nxt.mcycle} 
		= {swint, trint, exint, swint, trint, exint, regs.mcycle + 1};
		// Writeback: W stage
		unique if (exc_or_int) begin
			regs_nxt.mepc = pc_stored;
			regs_nxt.mcause = {~csr_ctl.is_except, mcause_name};
			regs_nxt.mstatus.mpie = regs.mstatus.mie;
			regs_nxt.mstatus.mie = '0;
			regs_nxt.mstatus.mpp = mode;
		end else if (csr_wen) begin
			unique case(csr_ctl.csr_name)
				CSR_MIE: regs_nxt.mie = wd;
				CSR_MIP:  regs_nxt.mip = wd;
				CSR_MTVEC: regs_nxt.mtvec = wd;
				CSR_MSTATUS: regs_nxt.mstatus = wd;
				CSR_MSCRATCH: regs_nxt.mscratch = wd;
				CSR_MEPC: regs_nxt.mepc = wd;
				CSR_MCAUSE: regs_nxt.mcause = wd;
				CSR_MCYCLE: regs_nxt.mcycle = wd;
				CSR_MTVAL: regs_nxt.mtval = wd;
				default: begin
					
				end	
			endcase
			regs_nxt.mstatus.sd = regs_nxt.mstatus.fs != 0;
		end else if (csr_ctl.is_mret) begin
			regs_nxt.mstatus.mie = regs_nxt.mstatus.mpie;
			regs_nxt.mstatus.mpie = 1'b1;
			regs_nxt.mstatus.mpp = 2'b0;
			regs_nxt.mstatus.xs = 0;
		end
		else begin end
	end
	
	// pc_nxt 
	assign csr_pc_nxt.csr_pc_valid = exc_or_int | csr_wen | csr_ctl.is_mret;
	always_comb begin
		if (exc_or_int) begin
			csr_pc_nxt.pc_nxt = regs.mtvec;
		end else if (csr_wen) begin
			csr_pc_nxt.pc_nxt = pcplus4;
		end else if (csr_ctl.is_mret) begin
			csr_pc_nxt.pc_nxt = regs.mepc;
		end else begin
			csr_pc_nxt.pc_nxt = 'x;
		end
	end

	//mode
	u2 mode;
	always_comb begin
		if (exc_or_int) begin
			mode_nxt = MACHINE_MODE;
		end else if (csr_ctl.is_mret) begin
			mode_nxt = regs.mstatus.mpp;
		end else 
			mode_nxt = mode;
	end
	
	always_ff @(posedge clk) begin
		if (reset) begin
			regs <= '0;
			regs.mcause[1] <= 1'b1;
			regs.mepc[31] <= 1'b1;
		end else begin
			regs <= regs_nxt;
		end
	end
	always_ff @(posedge clk) begin
		if (reset) begin
			mode <= MACHINE_MODE;
		end else begin
			mode <= mode_nxt;
		end
	end
	// assign pc_stored = pc_w != '0 ? pc_w : pc_m != '0 ? pc_m : pc_e != '0 ? pc_e : 
	// 	pc_d != '0 ? pc_d : pc_f;
	assign pc_stored = pc_w;
	// always_ff @(posedge clk) begin
	// 	if (reset) begin
	// 		pc_stored <= PCINIT;
	// 	end else begin
	// 		pc_stored <= pc_wb;
	// 	end
	// end
	
endmodule

`endif