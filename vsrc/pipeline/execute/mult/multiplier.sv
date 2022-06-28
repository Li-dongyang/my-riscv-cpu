`ifndef __MULTIPLIER_SV
`define __MULTIPLIER_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module multiplier 
    import common::*;
    import pipes::*;(
    input logic clk, reset, valid,
    input u64 A, B,
    output logic done,
    output u128 c
);
    u64 a, b;
    u41 p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11;
    u41 p_nxt0, p_nxt1, p_nxt2, p_nxt3, p_nxt4, p_nxt5, p_nxt6, p_nxt7, p_nxt8, p_nxt9, p_nxt10, p_nxt11;
    logic [24:0] e, f, g;
    logic [15:0] m, n, p, q;

    assign {a, b} = {A, B};
    assign e[13:0] = a[63:50];
    assign f = a[49:25];
    assign g = a[24:0];
    assign {m, n, p, q} = b;

    assign p_nxt0 = e * m;
    assign p_nxt1 = f * m;
    assign p_nxt2 = g * m;
    assign p_nxt3 = e * n;
    assign p_nxt4 = f * n;
    assign p_nxt5 = g * n;
    assign p_nxt6 = e * p;
    assign p_nxt7 = f * p;
    assign p_nxt8 = g * p;
    assign p_nxt9 = e * q;
    assign p_nxt10 = f * q;
    assign p_nxt11 = g * q;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            {p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11} <= '0;
        end else begin
            {p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11} <= 
                {p_nxt0, p_nxt1, p_nxt2, p_nxt3, p_nxt4, p_nxt5, p_nxt6, p_nxt7, p_nxt8, p_nxt9, p_nxt10, p_nxt11};
        end
    end
    u128 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11;
    u128 t0, t1, t2, t3;
    assign r0 = {p0[29:0], 98'b0};
    assign r1 = {14'b0, p1, 73'b0};
    assign r2 = {39'b0, p2, 48'b0};
    assign r3 = {5'b0, p3, 82'b0};
    assign r4 = {30'b0, p4, 57'b0};
    assign r5 = {55'b0, p5, 32'b0};
    assign r6 = {21'b0, p6, 66'b0};
    assign r7 = {46'b0, p7, 41'b0};
    assign r8 = {71'b0, p8, 16'b0};
    assign r9 = {37'b0, p9, 50'b0};
    assign r10 = {62'b0, p10, 25'b0};
    assign r11 = {87'b0, p11};

    assign t0 = r0 + r1 + r2;
    assign t1 = r3 + r4 + r5;
    assign t2 = r6 + r7 + r8;
    assign t3 = r9 + r10 + r11;
    assign c = t0 + t1 + t2 + t3;

    multicycle_state_t state, state_nxt;
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= INIT;
        end else begin
            state <= state_nxt;
        end
    end
    always_comb begin
        state_nxt = state;
        if (state == DOING) begin
            state_nxt = INIT;
        end else if (valid) begin
            state_nxt = DOING;
        end 
    end
    assign done = state_nxt == INIT;
    
endmodule

`endif 
