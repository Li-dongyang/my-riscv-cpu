`ifndef __FORWARD_SV
`define __FARWARD_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module forward_unit
    import common::*;
    import pipes::*;(
    // pipeline
    input instr_t dataD_instr, // cannot use dataD for logic current(inexplicable warnings from verilator)
    input decode_data_t dataD_o, // the wire is to dataD_o, or dataE
    input execute_data_t dataE_o, // means dataM, the clock is the same
    input memory_data_t dataM1,
    input memory_data_t dataM_o, // connect to dataM_o in the writeback part
    input writeback_data_t dataW, // need the result after writeback_src MUX
    output forward_t forward
);

    forward_type_t ae, be, sd, ad, bd;
    assign forward.forwardAD = ad;
    assign forward.forwardBD = bd;
    assign forward.forwardAE = ae;
    assign forward.forwardBE = be;
    assign forward.dataE_o = dataE_o;
    assign forward.dataM_o = dataM_o;
    assign forward.dataM1 = dataM1;
    assign forward.dataW = dataW;

    creg_addr_t Fo_ra1, Fo_ra2;
    assign Fo_ra1 = dataD_instr.ra1;
    assign Fo_ra2 = dataD_instr.ra2;

    // different from hardware/software interface
    always_comb begin : ae_forward
        if (dataE_o.instr.ctl.regwrite_en && 
            dataE_o.instr.writereg == dataD_o.instr.ra1 && 
            dataE_o.instr.writereg != '0) begin
                ae = FORWARDM;
        end
        else if (dataM1.instr.ctl.regwrite_en && 
            dataM1.instr.writereg == dataD_o.instr.ra1 && 
            dataM1.instr.writereg != '0) begin
                ae = FORWARDM1;
        end 
        else
            ae = NOFORWARD;
    end 
    always_comb begin : be_forward
        if (dataE_o.instr.ctl.regwrite_en && 
            dataE_o.instr.writereg == dataD_o.instr.ra2 && 
            dataE_o.instr.writereg != '0) begin
                be = FORWARDM;
        end
        else if (dataM1.instr.ctl.regwrite_en && 
            dataM1.instr.writereg == dataD_o.instr.ra2 && 
            dataM1.instr.writereg != '0) begin
                be = FORWARDM1;
        end 
        else
            be = NOFORWARD;
    end 

    // CSAPP graph 4-58, pay attention to the Sequence of M1/M/W/no
    always_comb begin : ad_forward
        if(dataE_o.instr.ctl.regwrite_en &&
            dataE_o.instr.writereg == Fo_ra1 &&
            dataE_o.instr.writereg != '0) begin
                ad = FORWARDM;
        end else if(dataM1.instr.ctl.regwrite_en &&
            dataM1.instr.writereg == Fo_ra1 &&
            dataM1.instr.writereg != '0) begin
                ad = FORWARDM1;
        end else if(dataM_o.instr.ctl.regwrite_en &&
            dataM_o.instr.writereg == Fo_ra1 &&
            dataM_o.instr.writereg != '0) begin
                ad = FORWARDW;
        end else
            ad = NOFORWARD;
    end  
    always_comb begin : bd_forward
        if(dataE_o.instr.ctl.regwrite_en &&
            dataE_o.instr.writereg == Fo_ra2 &&
            dataE_o.instr.writereg != '0) begin
                bd = FORWARDM;
        end else if(dataM1.instr.ctl.regwrite_en &&
            dataM1.instr.writereg == Fo_ra2 &&
            dataM1.instr.writereg != '0) begin
                bd = FORWARDM1;
        end else if(dataM_o.instr.ctl.regwrite_en &&
            dataM_o.instr.writereg == Fo_ra2 &&
            dataM_o.instr.writereg != '0) begin
                bd = FORWARDW;
        end else
            bd = NOFORWARD;
    end      

    // CSAPP p329 exercise 4.57
    // always_comb begin : sd_forward
    //     if (dataM_o.instr.ctl.memr_en && 
    //         dataM_o.instr.writereg == dataE_o.instr.ra2 && // only ra2 can be forwarded!!!
    //         dataM_o.instr.writereg != '0) begin
    //             sd = FORWARDW;
    //     end else
    //         sd = NOFORWARD;
    // end 

endmodule
`endif 