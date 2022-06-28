`ifndef __CBUSARBITER_SV
`define __CBUSARBITER_SV
`define NO_USE_MY


`ifdef VERILATOR
`include "include/common.sv"
`else

`endif
`ifdef USE_MY
typedef enum logic[1:0] { 
    IDLE, SERVEI, SERVED
} cbus_state_t;

/**
 this is comb logic version cbus arbiter,
 it'll always choose request[0], which is DATA request 
*/
module CBusArbiter
	import common::*;(
    input logic clk, reset,

    input  cbus_req_t  [1:0] ireqs,
    output cbus_resp_t [1:0] iresps,
    output cbus_req_t  oreq,
    input  cbus_resp_t oresp
);
    cbus_state_t state;
    always_ff @(posedge clk, posedge reset) begin
        if(reset)
            state <= IDLE;
        else begin
            unique case (state)
                IDLE: begin
                    if(ireqs[0].valid) begin // cbus is idle, so any request will be grand.
                        state <= SERVED;
                    end else if (ireqs[1].valid && ~ireqs[0].valid) begin
                        state <= SERVEI;
                    end
                end
                SERVEI: begin
                    if (oresp.last && ireqs[0].valid) state <= SERVED;
                    else if (ireqs[1].valid && ~ireqs[0].valid && oresp.last) state <= SERVEI;
                    else if (oresp.last) state <= IDLE;
                end
                // i cannot solve this: D finished, but i cannot make it default to SERVEI
                SERVED: begin
                    if (oresp.last) state <= IDLE; //pls use this for safety
                    // if (oresp.last) state <= SERVEI; //give it to servei then return to serveD if 2 D's adj.
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    assign oreq = state == SERVED ? ireqs[0] : state == SERVEI ? ireqs[1] : '0;
    assign iresps[0] = state == SERVED ? oresp : '0;
    assign iresps[1] = state == SERVEI ? oresp : '0;

endmodule

`else
/**
 * this implementation is not efficient, since
 * it adds one cycle lantency to all requests.
 */

module CBusArbiter
	import common::*;#(
    parameter int NUM_INPUTS = 2,  // NOTE: NUM_INPUTS >= 1

    localparam int MAX_INDEX = NUM_INPUTS - 1
) (
    input logic clk, reset,

    input  cbus_req_t  [MAX_INDEX:0] ireqs,
    output cbus_resp_t [MAX_INDEX:0] iresps,
    output cbus_req_t  oreq,
    input  cbus_resp_t oresp
);
    logic busy;
    int index, select;
    cbus_req_t saved_req, selected_req;

    // assign oreq = ireqs[index];
    assign oreq = busy ? ireqs[index] : '0;  // prevent early issue
    assign selected_req = ireqs[select];

    // select a preferred request
    always_comb begin
        select = 0;

        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (ireqs[i].valid) begin
                select = i;
                break;
            end
        end
    end

    // feedback to selected request
    always_comb begin
        iresps = '0;

        if (busy) begin
            for (int i = 0; i < NUM_INPUTS; i++) begin
                if (index == i)
                    iresps[i] = oresp;
            end
        end
    end

    always_ff @(posedge clk)
    if (~reset) begin
        if (busy) begin
            if (oresp.last)
                {busy, saved_req} <= '0;
        end else begin
            // if not valid, busy <= 0
            busy <= selected_req.valid;
            index <= select;
            saved_req <= selected_req;
        end
    end else begin
        {busy, index, saved_req} <= '0;
    end

    `UNUSED_OK({saved_req});
endmodule

`endif
`endif