`ifndef __DIVIDER_SV
`define __DIVIDER_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module divider 
    import common::*;
    import pipes::*;(
    input logic clk, reset, valid,
    input i64 A, B,
    output logic done, input_init,
    output u128 C // = {a % b, a / b}
);
    u64 a, b;
    u128 c;
    multicycle_state_t state, state_nxt;
    i67 count, count_nxt;

    assign input_init = state == INIT;
    assign {a, b} = {A, B};

    localparam i67 DIV_DELAY = {2'b0, 1'b1, 64'b0};
    always_ff @(posedge clk) begin
        if (reset) begin
            {state, count} <= '0;
        end else begin
            {state, count} <= {state_nxt, count_nxt};
        end
    end
    assign done = (state_nxt == INIT);
    always_comb begin
        {state_nxt, count_nxt} = {state, count}; 
        unique case(state)
            INIT: begin
                if (valid) begin
                    state_nxt = DOING;
                    count_nxt = DIV_DELAY;
                end 
            end
            DOING: begin
                count_nxt = {1'b0, count_nxt[66:1]};
                if (count_nxt == '0) begin
                    state_nxt = INIT;
                end
            end
        endcase
    end
    u128 p, p_nxt;
    always_comb begin
        p_nxt = p;
        unique case(state)
            INIT: begin
                p_nxt = {64'b0, a};
            end
            DOING: begin
                p_nxt = {p_nxt[126:0], 1'b0};
                if (p_nxt[127:64] >= b) begin
                    p_nxt[127:64] -= b;
                    p_nxt[0] = 1'b1;
                end
            end
        endcase
    end
    always_ff @(posedge clk) begin
        if (reset) begin
            p <= '0;
        end else begin
            p <= p_nxt;
        end
    end
    assign c = p;
    // assign C = (b == 0 && valid) ? {a, 64'hffffffffffffffff} : c;
    assign C = c;
endmodule

`endif
