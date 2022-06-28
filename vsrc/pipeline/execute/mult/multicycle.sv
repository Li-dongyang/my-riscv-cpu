`ifndef __MULTICYCLE_SV
`define __MULTICYCLE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/decode/decode_pkg.sv"
`include "pipeline/execute/mult/multiplier_top.sv"
`include "pipeline/execute/mult/divider_top.sv"
`else

`endif

module multicycle 
    import common::*;
    import pipes::*;
    import decode_pkg::*;(
    input clk, reset, flushDE, stalllDE,
    input op_t op,
    input is_32instr,
    input u64 a, b,
    output u64 multi_c,
    output logic doing
);
    u64 mul_c, div_c;
    logic muldone, divdone;

    multiplier_top mul_t(.clk, .reset, .op, 
        .a_in(a), .b_in(b), .c(mul_c), .done(muldone));
    divider_top div_t(.clk, .reset, .op, 
        .a_in(a), .b_in(b), .c(div_c), .done(divdone));

    assign multi_c = (op == MUL || op == MULW) ? mul_c : div_c;
    assign doing = ~(muldone & divdone);
endmodule

`endif 