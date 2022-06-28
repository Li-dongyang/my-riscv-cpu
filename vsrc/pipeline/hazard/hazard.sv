`ifndef __HAZARD_SV
`define __HAZARD_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module hazard
    import common::*;
    import pipes::*;(
    // pipeline
    input instr_t dataD_instr,
    input instr_t dataD_o_instr,
    input instr_t dataE_o_instr,
    input instr_t dataM_instr,
    input logic i_data_ok, d_data_ok,
    input logic bp_hit, multicycle_doing,
    output regflush_en_t regflush_en,
    output regstall_en_t regstall_en,
    output logic fetch_en
); 
    logic Do_regw_en, Do_memr_en, Eo_memr_en,M1_memr_en; 
    creg_addr_t Do_writereg, Eo_writereg,M1_writereg, Fo_ra1, Fo_ra2;
    assign Do_regw_en = dataD_o_instr.ctl.regwrite_en;
    assign Do_memr_en = dataD_o_instr.ctl.memr_en;
    assign Eo_memr_en = dataE_o_instr.ctl.memr_en;
    assign Do_writereg = dataD_o_instr.writereg;                           
    assign Eo_writereg = dataE_o_instr.writereg;
    assign M1_memr_en = dataM_instr.ctl.memr_en;
    assign M1_writereg = dataM_instr.writereg;                            
    assign Fo_ra1 = dataD_instr.ra1;
    assign Fo_ra2 = dataD_instr.ra2;

    // load/use stall & branch/jump stall
    logic lustall;//, bjstall;
    assign lustall = ( // dist(load, use) < 3
        Do_memr_en && Do_writereg != '0 &&
        ((Fo_ra1 == Do_writereg) || (Fo_ra2 == Do_writereg))
    ) || ( // above is use after load; below is 1.load 2.irrelevant_instr 3.use
        Eo_memr_en && Eo_writereg != '0 &&
        ((Fo_ra1 == Eo_writereg) || (Fo_ra2 == Eo_writereg))
    ) ||(
        M1_memr_en && M1_writereg != '0 &&
        ((Fo_ra1 == M1_writereg) || (Fo_ra2 == M1_writereg))
    );

    logic bjstall;
    assign bjstall = dataD_instr.ctl.bj != NOTHING && (
        (Do_regw_en && Do_writereg == Fo_ra1 && Do_writereg != '0) ||
        (Eo_memr_en && Eo_writereg == Fo_ra1 && Eo_writereg != '0) || 
        (// B_... instr will use rs2, so does BNE, etc., but j doesn't
            (dataD_instr.ctl.bj == B_BEQ) && (
                (Do_regw_en && Do_writereg == Fo_ra2 && Do_writereg != '0) ||
                (Eo_memr_en && Eo_writereg == Fo_ra2 && Eo_writereg != '0)
            )
        )
    );

    // d_data_ok means no mem visit or d_data's arrived.
    // d_data_ok and there are no stall+bubbles => can fetch instr
    assign fetch_en = d_data_ok & ~lustall & ~bjstall;

    // note: i_data stall, lustall, bjstall have same pipeline behavior
    assign regstall_en.pc = ~d_data_ok | ~i_data_ok | lustall | bjstall | multicycle_doing;
    assign regstall_en.fd = ~d_data_ok | ~i_data_ok | lustall | bjstall | multicycle_doing;
    assign regstall_en.de = ~d_data_ok | multicycle_doing;
    assign regstall_en.em = ~d_data_ok;
    assign regstall_en.mw = '0;

    assign regflush_en.fd = ( // branch predict not hit
                dataD_instr.ctl.bj == B_BEQ || dataD_instr.ctl.bj == J_JAL ||
                dataD_instr.ctl.bj == I_JALR ) && ~bp_hit; 
    assign regflush_en.de = lustall | bjstall | ~i_data_ok;
    assign regflush_en.em = multicycle_doing;
    assign regflush_en.mw = ~d_data_ok;

endmodule
`endif 