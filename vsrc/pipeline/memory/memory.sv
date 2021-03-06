`ifndef __MEMORY_SV
`define __MEMORY_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/memory/writedata.sv"
`else

`endif

module memory
    import common::*;
    import pipes::*; (
    input logic clk, reset,
	output dbus_req_t  dreq,
	input  dbus_resp_t dresp,
    // pipeline
    input execute_data_t dataE,
    input execute_data_t dataE_o,
    input forward_t forward,
    input logic csr_wen,
    output memory_data_t dataM,
    output logic stall_data_ok
);
    memory_data_t dataM1,dataM2,dataMtmp;
    instr_t instr;
    assign instr = dataE_o.instr;
    control_t ctl,ctl2;
    assign ctl = dataE_o.instr.ctl;
    assign ctl2 = dataE.instr.ctl;
    logic is_sd_missalign;
    // prepare data for dreq: strobe, formatted_memw_data.
    //strobe_t strobe;
    word_t raw_memw_data;
    //word_t formatted_memw_data; //data generated by writedata module 
    assign raw_memw_data = dataE_o.memw_data;
    // assign raw_memw_data = forward.forward_SD == FORWARDW ? forward.dataW.write_data : dataE_o.memw_data;
    writedata writedata(.addr(dataE_o.aluout[2:0]), ._wd(dataE_o.memw_data), .msize(ctl.msize),
            .wd(dataMtmp.formatted_memw_data), .strobe(dataMtmp.strobe), .is_sd_missalign);
    
    // exception
    csr_ctl_t csr_ctl;
    always_comb begin 
        csr_ctl = '0;
        csr_ctl.is_except = is_sd_missalign;
        csr_ctl.except_name = E_SD_MISALIGN;
    end

    // dreq
    assign dreq.valid = (state == MEMORY01||state==MEMORY11) ? 1 : (ctl.memr_en | ctl.memw_en) & ~csr_wen;
    assign dreq.addr = (state == MEMORY01||state==MEMORY11) ? dataM1.aluout : dataMtmp.aluout;
    assign dreq.size = (state == MEMORY01||state==MEMORY11) ? dataM1.instr.ctl.msize : dataMtmp.instr.ctl.msize;
    assign dreq.strobe = (state == MEMORY01||state==MEMORY11) ? (dataM1.instr.ctl.memw_en ? dataM1.strobe : '0) : (dataMtmp.instr.ctl.memw_en ? dataMtmp.strobe : '0);// strobe='0 when memr_en 
    assign dreq.data = (state == MEMORY01||state==MEMORY11) ? dataM1.formatted_memw_data : dataMtmp.formatted_memw_data;
    assign stall_data_ok=(state==IDLE && (ctl.memr_en || ctl.memw_en) && !csr_wen && !dresp.addr_ok)||(state==MEMORY10 && ~dresp.addr_ok )||(state == MEMORY11 && ~csr_wen);
    
    // end: dreq
    // dresp
    //assign dataMtmp.memr_data = dresp.data;
    //assign dataM1.memr_data = dresp.data;
    // assign d_data_ok = dresp.data_ok; // 'd better not to imple it here, core.sv instead

    // other outputs
    assign dataMtmp.instr = instr;

    assign dataMtmp.aluout = dataE_o.aluout; 
    assign dataMtmp.pc_and_instr = dataE_o.pc_and_instr;
    assign dataMtmp.pc_o = dataE_o.pc_o;
    assign dataMtmp.csr_ctl = is_sd_missalign & ctl.memw_en ? csr_ctl : dataE_o.csr_ctl;
    //assign dataMtmp.memr_data = dresp.data;

    assign dataM.aluout = dataM1.aluout;
    assign dataM.pc_o = dataM1.pc_o;
    assign dataM.instr = dataM1.instr;
    assign dataM.pc_and_instr = dataM1.pc_and_instr;
    assign dataM.csr_ctl = dataM1.csr_ctl;
    assign dataM.formatted_memw_data=dataM1.formatted_memw_data;
    assign dataM.memr_data =(state==IDLE)?dataM1.memr_data:dresp.data;

    enum { IDLE, MEMORY01, MEMORY10,MEMORY11 } state;
    always_ff @(posedge clk)
    if (~reset) begin
        unique case (state)
        IDLE:if((ctl.memr_en | ctl.memw_en) & ~csr_wen & dresp.addr_ok)begin
            state <= MEMORY01;
            dataM1 <= dataMtmp;
        end
        else if((ctl.memr_en | ctl.memw_en) & ~csr_wen) begin
            state<=MEMORY10;
            dataM1<=dataM1;
        end
            else begin
                state<=IDLE;
                //dataM2<=dataM1;
                dataM1<=dataMtmp;
            end

        MEMORY01: if(ctl.memr_en | ctl.memw_en)begin
                state<=MEMORY10;
                //dataM2<=dataM1;
                dataM1<=dataMtmp;
            end
            else begin
                state<=IDLE;
                //dataM2<=dataM1;
                dataM1 <= dataMtmp;
            end

        MEMORY10:if(dresp.addr_ok && dataMtmp.aluout[31]==0 && dreq.valid &&(ctl2.memr_en | ctl2.memw_en))begin
            state <= MEMORY10;
            dataM1.pc_o <= dataMtmp.pc_o;
            dataM1.aluout <= dataMtmp.aluout;
            dataM1.pc_and_instr <= dataMtmp.pc_and_instr;
            dataM1.csr_ctl <=dataMtmp.csr_ctl;
            dataM1.formatted_memw_data <=dataMtmp.formatted_memw_data;
            dataM1.strobe <=dataMtmp.strobe;
            dataM1.instr <= dataMtmp.instr;
            dataM1.memr_data <= dresp.data;
        end else if(dresp.addr_ok && dataMtmp.aluout[31]==0 && dreq.valid)begin
            state <= IDLE;
            dataM1.pc_o <= dataMtmp.pc_o;
            dataM1.aluout <= dataMtmp.aluout;
            dataM1.pc_and_instr <= dataMtmp.pc_and_instr;
            dataM1.csr_ctl <=dataMtmp.csr_ctl;
            dataM1.formatted_memw_data <=dataMtmp.formatted_memw_data;
            dataM1.strobe <=dataMtmp.strobe;
            dataM1.instr <= dataMtmp.instr;
            dataM1.memr_data <= dresp.data;
        end
        else if (dresp.addr_ok && dreq.valid &&(ctl2.memr_en | ctl2.memw_en)) begin
            state  <= MEMORY11;
            //dataM2<=dataM1;
            dataM1<=dataMtmp;
        end else if(dresp.addr_ok && dreq.valid)begin
                state<=MEMORY01;
                //dataM2<=dataM2;
                dataM1<=dataMtmp;
        end
            else begin
                state <= MEMORY10;
                //dataM2<=dataM2;
                dataM1<=dataM1;
            end

        MEMORY11: if (csr_wen)begin
            state  <= IDLE;
            //dataM2<=dataM1;
            dataM1<=dataMtmp;
        end
            else begin
                state  <= MEMORY10;
                //dataM2<=dataM2;
                dataM1<=dataM1;
            end
        default:begin
        end
        endcase
    end else begin
        state <= IDLE;
        dataM1 <= '0;
    end

endmodule
`endif 