`ifndef __TWOBITCONTER_SV
`define __TWOBITCONTER_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

typedef enum logic[1:0] { 
    SNTAKEN, WNTAKEN, WTAKEN, STAKEN
} state_t;

module TwoBitCounter
	import common::*;
    import pipes::*;(
    input logic clk, reset, en, wen,
    input logic is_taken,
    output pcsrc_t bp_pcsrc
    );

    logic jump;
    state_t state;
    always_ff @(posedge clk, posedge reset) begin 
        if(reset) begin
            jump <= 0;
            state <= WTAKEN;
        end else if(wen & en) begin
            case (state)
                SNTAKEN: begin
                    jump <= 0;
                    state <= is_taken ? WNTAKEN : SNTAKEN;
                end
                WNTAKEN: begin
                    jump <= 0;
                    state <= is_taken ? STAKEN : SNTAKEN;
                end
                WTAKEN: begin
                    jump <= 1;
                    state <= is_taken ? STAKEN : SNTAKEN;
                end
                STAKEN: begin
                    jump <= 1;
                    state <= is_taken ? STAKEN : WTAKEN;
                end
                default: begin
                    jump <= 0;
                    state <= WNTAKEN;
                end
            endcase
        end
    end

    assign bp_pcsrc = jump ? PCJUMP : PCPLUS4;
endmodule
`endif 