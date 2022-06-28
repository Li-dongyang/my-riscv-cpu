`ifndef __PCSELECT_SV
`define __PCSELECT_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module pcselect
	import common::*;
    import pipes::*;(
    input logic reset,
    input addr_t pc,
    output addr_t pc_o,
    // control
    input pcsrc_t pcsrc,
    input pchold_t pc_hold,
    input csr_pc_nxt_t csr_pc_nxt,
    input addr_t pc_jump
);
    addr_t pc_plus4;

    always_comb begin 
        if(reset) 
            pc_o = PCINIT;
        else if(csr_pc_nxt.csr_pc_valid)
            pc_o = csr_pc_nxt.pc_nxt;
        else if(pc_hold == PCHOLD)
            pc_o = pc;
        else
            pc_o = pc_jump;

        // if(reset) 
        //     pc_o = PCINIT;
        // else if(pc_hold == PCHOLD)
        //     pc_o = pc;
        // else if(pcsrc == PCJUMP) 
        //     pc_o = pc_jump;
        // else begin
        //     pc_o = pc_plus4;
        // end
    end

    // pc + 4
    // assign pc_plus4 = pc + 64'b100;

endmodule
`endif 