`ifndef __CORE_SV
`define __CORE_SV

`define NO_SINGLE
`define NO_DISPLAY

`ifdef VERILATOR
`include "include/common.sv"
`include "pipeline/regfile/regfile.sv"
`include "pipeline/regfile/pipereg.sv"
//`include "pipeline/regfile/pipewire.sv"
`include "include/pipes.sv"
`include "pipeline/fetch/fetch.sv"
`include "pipeline/decode/decode.sv"
`include "pipeline/execute/execute.sv"
`include "pipeline/memory/memory.sv"
`include "pipeline/writeback/writeback.sv"
`include "pipeline/hazard/hazard.sv"
`include "pipeline/forward/forward_unit.sv"
`include "pipeline/csr/csr_pkg.sv"
`include "pipeline/csr/csr.sv"

`else

`endif

module core 
	import common::*;
	import pipes::*;
	import csr_pkg::*;(
	input logic clk, reset,
	output ibus_req_t  ireq,
	input  ibus_resp_t iresp,
	output dbus_req_t  dreq,
	input  dbus_resp_t dresp,
	input logic trint, swint, exint
);
	/* TODO: Add your pipeline here. */
	fetch_data_t dataF, dataF_o;
	decode_data_t dataD, dataD_o;
	execute_data_t dataE, dataE_o;
	memory_data_t dataM, dataM_o;
	writeback_data_t dataW;
	regflush_en_t regflush_en;
   	regstall_en_t regstall_en;
	forward_t forward_ctl;
	instr_t dataD_instr;

    regfile_i_t regfile_i;
    regfile_o_t regfile_o;
	logic fetch_en, bp_hit, multicycle_doing, stall_data_ok;
	bp_result_t instr_commit;

	csr_pc_nxt_t csr_pc_nxt;
	csr_write_to_reg_t csr_write_to_reg;
	csr_ctl_t csr_ctl;
	csr_regs_t regs_nxt;
	u2 mode_nxt;
	logic csr_flush;
	assign csr_flush = csr_pc_nxt.csr_pc_valid; 
`ifdef DISPLAY
	always_ff @(posedge clk) begin 
		$display("%x %x %d", dataF.pc_o, 
			dataF_o.pc_o, dataM_o.instr.op); 
		if(dataM_o.pc_and_instr.pc_o == 64'h0000000080000018) begin
			$finish;
		end
	end
`endif

	fetch fetch(.clk, .reset(reset),
		.ireq, .iresp,
		.dataF, 
		.fetch_en, .bp_hit, .instr_commit, .commit_instr_bj(dataD_instr.ctl.bj),// all from decode/changepcsrc.sv
		.pc_hold(regstall_en.pc ? PCHOLD: PCEN),
		.csr_pc_nxt
	);
	
	decode decode (
		.dataF(dataF_o), .dataD, .dataD_instr,
		.instr_commit, .bp_hit,
		.regfile_i, .regfile_o,
		.forward(forward_ctl)
	);

	execute execute (
		.clk, .reset(reset | csr_flush), .flushDE(regflush_en.de), .stalllDE(regstall_en.de),
		.dataD(dataD_o), .dataE, .multicycle_doing,
		.forward(forward_ctl)
	);

	memory memory (
		.clk, .reset(reset | csr_flush),
		.dreq, .dresp,
		.dataE, .dataE_o, .dataM,
		.forward(forward_ctl), .csr_wen(csr_flush),
		.stall_data_ok
	);

	writeback writeback (
		.dataM(dataM_o), .dataW,
		.csr_ctl, .csr_write_to_reg
	);

`ifdef _SINGLE
	initial begin
		dreq = '0;
		ireq = '0;
		dataF = '0;
		dataD = '0;
		dataW = '0;
	end

	assign dataF_o = dataF;
	assign dataD_o = dataD;
	assign dataE_o = dataE;
	assign dataM_o = dataM;

`else
	hazard hazard (
		.dataD_instr, .dataD_o_instr(dataD_o.instr), .dataE_o_instr(dataE_o.instr), 
		.dataM_instr(dataM.instr), 
		.i_data_ok(iresp.data_ok | ~ireq.valid), .d_data_ok(~stall_data_ok),
		.bp_hit, .multicycle_doing,
		.regflush_en, .regstall_en, .fetch_en
	);

	forward_unit forward (
		.dataD_instr,
		.dataD_o, .dataE_o,.dataM1(dataM),.dataM_o, .dataW,
		.forward(forward_ctl)
	);

	csr csr (
		.clk, .reset, 
		.dataM(dataM_o), .swint, .trint, .exint, .csr_ctl,
		.csr_write_to_reg, .csr_pc_nxt,
		.regs_nxt, .mode_nxt
	);

	pipereg #(.T(fetch_data_t)) fd (
		.clk, .reset(reset | csr_flush), 
		.in(dataF), .out(dataF_o),
		.flush_en(regflush_en.fd), .en(~regstall_en.fd)
	);

	pipereg #(.T(decode_data_t)) de (
		.clk, .reset(reset | csr_flush), 
		.in(dataD), .out(dataD_o),
		.flush_en(regflush_en.de), .en(~regstall_en.de)
	);

	pipereg #(.T(execute_data_t)) em (
		.clk, .reset(reset | csr_flush), 
		.in(dataE), .out(dataE_o),
		.flush_en(regflush_en.em), .en(~regstall_en.em)
	);

	pipereg #(.T(memory_data_t)) mw (
		.clk, .reset(reset | csr_flush), 
		.in(dataM), .out(dataM_o),
		.flush_en(regflush_en.mw), .en(~regstall_en.mw)
	);
`endif	

	regfile regfile(
		.clk, .reset,
		.ra1(regfile_i.ra1),
		.ra2(regfile_i.ra2),
		.rd1(regfile_o.rd1),
		.rd2(regfile_o.rd2),
		.wvalid(dataW.regwrite_en),
		.wa(dataW.writereg), // {creg_data_t}
		.wd(dataW.write_data)
	);

`ifdef VERILATOR
	DifftestInstrCommit DifftestInstrCommit(
		.clock              (clk),
		.coreid             (0), // no change
		.index              (0), // using in issue
		.valid              ((~reset) && dataM_o.pc_and_instr.raw_instr != 32'b0), // no commit instr or the commit instr is a bubble or reset is true => '0
		.pc                 (dataM_o.pc_and_instr.pc_o), // the pc of this instr
		.instr              (dataM_o.pc_and_instr.raw_instr), // no change
		.skip               ((dataM_o.instr.ctl.memr_en | dataM_o.instr.ctl.memw_en) & (dataM_o.aluout[63:31] == '0)), // (the instr r || w in memory) and addr[31] == 0 => 1
		.isRVC              (0), // no change
		.scFailed           (0), // no change
		.wen                (dataW.regwrite_en), // write to General-Purpose Registers ? 1 : 0 
		.wdest              ({3'b000, dataW.writereg}), // which General-Purpose Registers to write, width:{000, creg_addr_t}
		.wdata              (dataW.write_data)  // the data to write
	);
	      
	DifftestArchIntRegState DifftestArchIntRegState (
		.clock              (clk),
		.coreid             (0),
		.gpr_0              (regfile.regs_nxt[0]),
		.gpr_1              (regfile.regs_nxt[1]),
		.gpr_2              (regfile.regs_nxt[2]),
		.gpr_3              (regfile.regs_nxt[3]),
		.gpr_4              (regfile.regs_nxt[4]),
		.gpr_5              (regfile.regs_nxt[5]),
		.gpr_6              (regfile.regs_nxt[6]),
		.gpr_7              (regfile.regs_nxt[7]),
		.gpr_8              (regfile.regs_nxt[8]),
		.gpr_9              (regfile.regs_nxt[9]),
		.gpr_10             (regfile.regs_nxt[10]),
		.gpr_11             (regfile.regs_nxt[11]),
		.gpr_12             (regfile.regs_nxt[12]),
		.gpr_13             (regfile.regs_nxt[13]),
		.gpr_14             (regfile.regs_nxt[14]),
		.gpr_15             (regfile.regs_nxt[15]),
		.gpr_16             (regfile.regs_nxt[16]),
		.gpr_17             (regfile.regs_nxt[17]),
		.gpr_18             (regfile.regs_nxt[18]),
		.gpr_19             (regfile.regs_nxt[19]),
		.gpr_20             (regfile.regs_nxt[20]),
		.gpr_21             (regfile.regs_nxt[21]),
		.gpr_22             (regfile.regs_nxt[22]),
		.gpr_23             (regfile.regs_nxt[23]),
		.gpr_24             (regfile.regs_nxt[24]),
		.gpr_25             (regfile.regs_nxt[25]),
		.gpr_26             (regfile.regs_nxt[26]),
		.gpr_27             (regfile.regs_nxt[27]),
		.gpr_28             (regfile.regs_nxt[28]),
		.gpr_29             (regfile.regs_nxt[29]),
		.gpr_30             (regfile.regs_nxt[30]),
		.gpr_31             (regfile.regs_nxt[31])
	);
	      
	DifftestTrapEvent DifftestTrapEvent(
		.clock              (clk),
		.coreid             (0),
		.valid              (0),
		.code               (0),
		.pc                 (0),
		.cycleCnt           (0),
		.instrCnt           (0)
	);
	      
	DifftestCSRState DifftestCSRState(
		.clock              (clk),
		.coreid             (0),
		.priviledgeMode     (mode_nxt),
		.mstatus            (regs_nxt.mstatus),
		.sstatus            (regs_nxt.mstatus & 64'h800000030001e000),
		.mepc               (regs_nxt.mepc),
		.sepc               (0),
		.mtval              (regs_nxt.mtval),
		.stval              (0),
		.mtvec              (regs_nxt.mtvec),
		.stvec              (0),
		.mcause             (regs_nxt.mcause),
		.scause             (0),
		.satp               (0),
		.mip                (regs_nxt.mip),
		.mie                (regs_nxt.mie),
		.mscratch           (regs_nxt.mscratch),
		.sscratch           (0),
		.mideleg            (0),
		.medeleg            (0)
	      );
	      
	DifftestArchFpRegState DifftestArchFpRegState(
		.clock              (clk),
		.coreid             (0),
		.fpr_0              (0),
		.fpr_1              (0),
		.fpr_2              (0),
		.fpr_3              (0),
		.fpr_4              (0),
		.fpr_5              (0),
		.fpr_6              (0),
		.fpr_7              (0),
		.fpr_8              (0),
		.fpr_9              (0),
		.fpr_10             (0),
		.fpr_11             (0),
		.fpr_12             (0),
		.fpr_13             (0),
		.fpr_14             (0),
		.fpr_15             (0),
		.fpr_16             (0),
		.fpr_17             (0),
		.fpr_18             (0),
		.fpr_19             (0),
		.fpr_20             (0),
		.fpr_21             (0),
		.fpr_22             (0),
		.fpr_23             (0),
		.fpr_24             (0),
		.fpr_25             (0),
		.fpr_26             (0),
		.fpr_27             (0),
		.fpr_28             (0),
		.fpr_29             (0),
		.fpr_30             (0),
		.fpr_31             (0)
	);
	
`endif
endmodule
`endif