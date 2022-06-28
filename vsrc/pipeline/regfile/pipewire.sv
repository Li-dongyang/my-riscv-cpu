`ifndef __PIPEWIRE_SV
`define __PIPEWIRE_SV
`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif
module pipewire
    import common::*;
    import pipes::*; #(
    parameter type T = logic
)(
    input logic clk, reset,
    input T in,
    output T out,
    input logic flush_en, en
);  
    // T flush = '0;
    // always_comb begin
    //     if (reset | flush_en) begin
    //         out = flush; 
    //     end else if (en) begin
    //         out = in;
    //     end else 
    //         out = in;
    // end
    assign out = in;
    
endmodule



`endif