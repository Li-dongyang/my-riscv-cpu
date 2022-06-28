`ifndef __WRITEBACK_SV
`define __WRITEBACK_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/writeback/readdata.sv"
`else

`endif

module writeback
    import common::*;
    import pipes::*; (
    // pipeline
    input memory_data_t dataM,
    output writeback_data_t dataW,
    // CSR
    input csr_write_to_reg_t csr_write_to_reg,
    output csr_ctl_t csr_ctl
);
    instr_t instr;
    assign instr = dataM.instr;
    control_t ctl;
    assign ctl = dataM.instr.ctl;
    word_t dataW_memr_data; // data extract from readdata
    logic is_ld_missalign;

    // readdata: called by byte-level read instr
    readdata readdata(._rd(dataM.memr_data), .rd(dataW_memr_data),
        .addr(dataM.aluout[2:0]), .msize(ctl.msize), .mem_unsigned(ctl.mem_unsigned),
        .is_ld_missalign);

    // exception
    csr_ctl_t csr_ctl_wb;
    always_comb begin 
        csr_ctl_wb = '0;
        csr_ctl_wb.is_except = is_ld_missalign;
        csr_ctl_wb.except_name = E_LD_MISALIGN;
    end
    assign csr_ctl = is_ld_missalign & ctl.memr_en ? csr_ctl_wb : dataM.csr_ctl;
    u64 data_from_calculate;
    assign data_from_calculate = csr_write_to_reg.csr_write_to_reg_en ? csr_write_to_reg.csr_write_to_reg_data : dataM.aluout;
    assign dataW.writereg = instr.writereg;
    assign dataW.regwrite_en = ctl.regwrite_en;
    assign dataW.write_data = ctl.writeback_src == ALURESULT ?
                                data_from_calculate : dataW_memr_data;
    //display

endmodule
`endif 