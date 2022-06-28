`ifndef __PIPEREG_SV
`define __PIPEREG_SV
`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif
module pipereg
    import common::*;
    import pipes::*; #(
    parameter type T = logic
)(
    input logic clk, reset,
    input T in,
    output T out,
    input logic flush_en, en
);  
    T flush = '0;
    always_ff @(posedge clk) begin
        if (reset) begin
            out <= flush; 
        end else if (~en) begin //stall
            out <= out;
        end else if(flush_en) begin
            out <= flush;
        end else 
            out <= in;
    end
    
endmodule



`endif