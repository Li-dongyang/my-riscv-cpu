`ifndef __DIVIDER_TOP_SV
`define __DIVIDER_TOP_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/decode/decode_pkg.sv"
`include "pipeline/execute/mult/divider.sv"
`else

`endif

module divider_top 
    import common::*;
    import pipes::*;
    import decode_pkg::*;(
    input logic clk, reset,
    input op_t op,
    input u64 a_in, b_in,
    output logic done,
    output u64 c
);
    u128 div_c;
    u64 A, B, sign_tmp, a, b, a_store, b_store;
    logic divvalid, input_init;

    always_ff @(posedge clk) begin 
        if(reset) 
            {a_store, b_store} <= '0;
        else if(divvalid && input_init) 
            {a_store, b_store} <= {a_in, b_in};
        else 
            {a_store, b_store} <= {a_store, b_store};
    end
    assign a = (divvalid && input_init) ? a_in : a_store;
    assign b = (divvalid && input_init) ? b_in : b_store;

    always_comb begin
        {A, B, sign_tmp, divvalid} = '0;
        unique case (op)
            DIV: begin
                if (b_in == 0 && input_init) begin // b_in does equal to 0 then we leave at once, no multicycle!
                    c = '1;
                    divvalid = 0;
                end else begin
                    divvalid = 1;
                    A = a[63] ? -a: a;
                    B = b[63] ? -b: b;
                    c = (a[63] ^ b[63]) ? -div_c[63:0]: div_c[63:0];
                end
            end
            DIVU: begin
                if (b_in == 0 && input_init) begin
                    c = '1;
                    divvalid = 0;
                end else begin
                    divvalid = 1;
                    {A, B} = {a, b};
                    c = div_c[63:0];
                end
            end
            REM: begin
                if (b_in == 0 && input_init) begin
                    c = a_in;
                    divvalid = 0;
                end else begin
                    divvalid = 1;
                    A = a[63] ? -a: a;
                    B = b[63] ? -b: b;
                    c = (a[63] ^ div_c[127]) ? -div_c[127:64]: div_c[127:64];
                end
            end
            REMU: begin
                if (b_in == 0 && input_init) begin
                    c = a_in;
                    divvalid = 0;
                end else begin 
                    divvalid = 1;
                    {A, B} = {a, b};
                    c = div_c[127:64];
                end
            end
            DIVW: begin
                if (b_in[31:0] == 0 && input_init) begin
                    c = '1;
                    divvalid = 0;
                end else begin
                    divvalid = 1;
                    A[31:0] = a[31] ? -(a[31:0]) : a[31:0];
                    B[31:0] = b[31] ? -(b[31:0]) : b[31:0];
                    sign_tmp[31:0] = (a[31] ^ b[31]) ? -(div_c[31:0]): (div_c[31:0]);
                    c = {{32{sign_tmp[31]}}, sign_tmp[31:0]};
                end
            end
            DIVUW: begin
                if (b_in[31:0] == 0 && input_init) begin
                    c = '1;
                    divvalid = 0;
                end else begin
                    divvalid = 1;
                    {A, B} = {32'b0, a[31:0], 32'b0, b[31:0]};
                    c = {{32{div_c[31]}}, div_c[31:0]};
                end
            end
            REMW: begin
                if (b_in[31:0] == 0 && input_init) begin
                    c = {{32{a_in[31]}}, a_in[31:0]};
                    divvalid = 0;
                end else begin
                    divvalid = 1;
                    A[31:0] = a[31] ? -(a[31:0]) : a[31:0];
                    B[31:0] = b[31] ? -(b[31:0]) : b[31:0];
                    sign_tmp[31:0] = (a[31] ^ div_c[95]) ? -(div_c[95:64]): div_c[95:64];
                    c = {{32{sign_tmp[31]}}, sign_tmp[31:0]};
                end
            end
            REMUW: begin
                if (b_in[31:0] == 0 && input_init) begin
                    c = {{32{a_in[31]}}, a_in[31:0]};
                    divvalid = 0;
                end else begin
                    divvalid = 1;
                    {A, B} = {32'b0, a[31:0], 32'b0, b[31:0]};
                    c = {{32{div_c[95]}}, div_c[95:64]};
                end
            end
            default: 
                {B, A, c, divvalid} = '0;
        endcase
    end

    divider div0(.clk, .reset, .valid(divvalid), 
        .A, .B, .C(div_c), .done, .input_init);
endmodule

`endif 
