`ifndef __MULTIPLIER_TOP_SV
`define __MULTIPLIER_TOP_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/decode/decode_pkg.sv"
`include "pipeline/execute/mult/multiplier.sv"
`else

`endif

module multiplier_top
    import common::*;
    import pipes::*;
    import decode_pkg::*;(
    input logic clk, reset,
    input op_t op,
    input u64 a_in, b_in,
    output logic done,
    output u64 c
);
    u128 mul_c;
    u64 A, B, sign_tmp, a_store, b_store, a, b;
    logic mulvalid;

    always_ff @(posedge clk) begin 
        if(reset) 
            {a_store, b_store} <= '0;
        else if(~done) 
            {a_store, b_store} <= {a_in, b_in};
        else 
            {a_store, b_store} <= {a_store, b_store};
    end
    assign a = (~done & mulvalid) ? a_in : a_store; // attention! right only on this 2 cycle multiply
    assign b = (~done & mulvalid) ? b_in : b_store;

    always_comb begin
        {A, B, mulvalid} = '0;
        unique case (op)
            MUL: begin
                mulvalid = 1;
                A = a[63] ? -a: a;
                B = b[63] ? -b: b;
                c = (a[63] ^ b[63]) ? -mul_c[63:0]: mul_c[63:0];
            end
            MULW: begin
                mulvalid = 1;
                A[31:0] = a[31] ? -(a[31:0]) : a[31:0];
                B[31:0] = b[31] ? -(b[31:0]) : b[31:0];
                sign_tmp[31:0] = (a[31] ^ b[31]) ? -(mul_c[31:0]): (mul_c[31:0]);
                c = {{32{sign_tmp[31]}}, sign_tmp[31:0]};
            end
            default: 
                {B, A, c, mulvalid} = '0;
        endcase
    end

    multiplier mul0(.clk, .reset, .valid(mulvalid), 
        .A, .B, .c(mul_c), .done);

endmodule

`endif 