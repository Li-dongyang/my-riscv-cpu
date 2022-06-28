
`define PRINT_MISS_RATE
`define OFFSETBITS 4
`define IDXBITS 3
`ifndef __DCACHE_SV
`define __DCACHE_SV

`ifdef VERILATOR
`include "include/common.sv"
/* You should not add any additional includes in this file */
`endif

module DCache 
	import common::*; #(
		/* You can modify this part to support more parameters */
		/* e.g. OFFSET_BITS, INDEX_BITS, TAG_BITS */
        parameter OFFSET_BITS = `OFFSETBITS,
        parameter INDEX_BITS = 8,
        parameter TAG_BITS = 18,
        parameter IDX_BITS = `IDXBITS,
        parameter WORD_BYTES = 8,
        parameter PADDR_WIDTH = 64,

        localparam NUM_WAYS = 2 ** IDX_BITS,
        localparam NUM_SETS = 2 ** INDEX_BITS,
        localparam NUM_WORDS = 2 ** OFFSET_BITS,
        localparam ZEROS = $clog2(WORD_BYTES),

        localparam USED_ADDR_WIDTH = OFFSET_BITS + INDEX_BITS + TAG_BITS + ZEROS,
        localparam UNUSED_ADDR_WIDTH = PADDR_WIDTH - USED_ADDR_WIDTH,
        localparam CACHE_ADDR_WIDTH = IDX_BITS + INDEX_BITS + OFFSET_BITS,
        localparam CACHE_DATA_WIDTH = 8 * WORD_BYTES,

        localparam type idx_t = logic[IDX_BITS-1: 0],
        localparam type tag_t = logic[TAG_BITS - 1: 0],
        localparam type offset_t = logic[OFFSET_BITS-1: 0],
        localparam type index_t = logic[INDEX_BITS - 1: 0],
        localparam type zeros_t = logic[ZEROS-1: 0],
        localparam type tag_ram_data_t = tag_t[NUM_WAYS-1 : 0],
        localparam type meta_t = struct packed {
            logic valid;
            logic dirty;
        },
        localparam type meta_ram_data_t = meta_t[NUM_WAYS-1 : 0],
        localparam type select_t = logic[NUM_WAYS-2: 0],

        localparam type cache_addr_t = struct packed {
            idx_t idx;
            index_t index;
            offset_t offset;
        },
        localparam type req_addr_t = struct packed {
            tag_t tag;
            index_t index;
            offset_t offset;
            zeros_t zeros;
        },
        localparam type writebuffer_t = u64 [NUM_WORDS-1 : 0]
	)(
	input logic clk, reset,

	input  dbus_req_t  dreq,
    output dbus_resp_t dresp,
    output cbus_req_t  creq,
    input  cbus_resp_t cresp
);

`ifndef REFERENCE_CACHE

	cache_addr_t cache_addr, miss_addr;
    req_addr_t req_addr, creq_addr;
    logic skip;
    assign req_addr = dreq.addr[USED_ADDR_WIDTH-1: 0];

    cbus_req_t creq_skip, creq_no_skip;
    assign skip = dreq.addr[31] == 0 && dreq.valid && miss_state == IDLE;
    
    // cache_addr & miss_addr
    idx_t idx, miss_idx;
    assign cache_addr.idx = idx;
    assign cache_addr.index = req_addr.index;
    assign cache_addr.offset = req_addr.offset;

    tag_ram_data_t tags, tags_nxt;
    select_t selects, selects_nxt;
    
    enum { IDLE, LOAD, WRITEBACK } miss_state;

    // tag ram
    RAM_SinglePort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(tag_ram_data_t)),
        .BYTE_WIDTH($bits(tag_ram_data_t))
    ) tag_ram (
        .clk, .en(1),
        .addr(req_addr.index),
        .strobe(1),
        .wdata(tags_nxt),
        .rdata(tags)
    );
    // select ram, for psudo LRU
    RAM_SinglePort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(select_t)),
        .BYTE_WIDTH($bits(select_t))
    ) select_ram (
        .clk, .en(1),
        .addr(req_addr.index),
        .strobe(1),
        .wdata(selects_nxt),
        .rdata(selects)
    );
    // dirty and valid
    meta_ram_data_t metadatai_nxt;
    meta_ram_data_t [NUM_SETS-1: 0] metadata;// this is one hot
    always_ff @(posedge clk) begin 
        if(reset) begin
            metadata <= '0;
        end else begin
            metadata[req_addr.index] <= metadatai_nxt;
        end
    end

    logic fsm_to_hit, is_hit, fsm_to_miss;
    u64 hit_rdata, miss_wdata, miss_rdata;
    strobe_t miss_strobe;
    assign miss_strobe = miss_state == LOAD && cresp.ready ? {WORD_BYTES{1'b1}} : '0;
    assign miss_wdata = cresp.data;

    // is_hit ?
    meta_ram_data_t metai;
    assign metai = metadata[req_addr.index];
    logic [NUM_WAYS - 1: 0] hit_bits;
    for (genvar i = 0; i < NUM_WAYS; i++) begin
        assign hit_bits[i] = metai[i].valid &&
            req_addr.tag == tags[i];
    end
    assign is_hit = |hit_bits; // equals to hit_bits != 0;
    // gen idx, can only be used in 8-way
    assign idx[0] = hit_bits[1] | hit_bits[3] | hit_bits[5] | hit_bits[7]; 
    assign idx[2] = hit_bits[4] | hit_bits[5] | hit_bits[6] | hit_bits[7]; 
    assign idx[1] = hit_bits[2] | hit_bits[3] | hit_bits[6] | hit_bits[7]; 

    always_comb begin : new_tag_metadata_comb
        metadatai_nxt = metai;
        tags_nxt = tags;
        if(fsm_to_hit) begin
            if(dreq.strobe != 0) begin
                metadatai_nxt[idx].dirty = 1'b1;
            end 
        end else if (fsm_to_miss) begin
            {metadatai_nxt[miss_idx].valid, metadatai_nxt[miss_idx].dirty} = 2'b10;
            tags_nxt[miss_idx] = req_addr.tag;
        end
    end : new_tag_metadata_comb
    // can only be used in 8-way!!!
    always_comb begin : new_select_comb 
        selects_nxt = selects;
        if (fsm_to_hit) begin
            selects_nxt[6] = idx[2];
            selects_nxt[5] = idx[2] ? selects[5] : idx[1];
            selects_nxt[4] = idx[2] ? idx[1] : selects[5];
            unique case (idx[2:1])
                2'b00: selects_nxt[3] = idx[0];
                2'b01: selects_nxt[2] = idx[0]; 
                2'b10: selects_nxt[1] = idx[0]; 
                2'b11: selects_nxt[0] = idx[0]; 
                default: begin
                    // no need to write default!
                end
            endcase
        end
    end : new_select_comb
    // gen miss_addr.idx // can only be used in 8-way!!!
    always_comb begin : new_miss_idx_
        miss_idx[2] = ~selects[6];
        miss_idx[1] = ~selects[6] ? ~selects[5] : ~selects[4];
        miss_idx[0] = ~selects[{1'b0, ~miss_idx[2], ~miss_idx[1]}];
        for (int i = 0; i < NUM_WAYS; i++) begin
            if( !metai[i].valid ) 
                miss_idx = idx_t'(i);
        end
    end : new_miss_idx_
    
    // writeback buffer, size: one cache line
    writebuffer_t writebuffer;
    idx_t wb_idx;
    offset_t wb_offset;
    tag_t wb_tag;
    index_t wb_index;
    meta_t wb_meta;
    logic wb_wen;

    // FSM and WRITEBACK data from cbus
    // comb logic outside the ff
    logic is_miss_data_loaded, fsm_in_miss;
    logic[NUM_WORDS-1: 0] miss_data_loaded;
    assign fsm_in_miss = miss_state != IDLE && req_addr.tag == creq_addr.tag && miss_addr.index == req_addr.index;
    assign is_miss_data_loaded = ~fsm_in_miss || miss_data_loaded[req_addr.offset];
    // !skip
    assign fsm_to_hit = is_hit && !skip && (dreq.valid && is_miss_data_loaded);
    // miss_state to LOAD and only last one cycle, that's why it has so many constrains
    assign fsm_to_miss = ~is_hit && !(dreq.addr[31] == 0 && dreq.valid) && dreq.valid && (miss_state == IDLE || miss_state == WRITEBACK && cresp.last);

    logic dresp_data_ok;
    offset_t offset_cnt;
    always_ff @(posedge clk) begin : cache_fsm
        if(reset) begin
            dresp_data_ok <= 0;
            miss_state <= IDLE;
            miss_addr <= '0;
            miss_data_loaded <= '0;
            {wb_tag, wb_meta, wb_wen, wb_offset} <= '0;
        end else begin
            // d_data_ok to 0, because data output is one cycle behind the tag comparation
            dresp_data_ok <= dresp_data_ok ? 0 :fsm_to_hit; 
        
            // miss_state, LOAD, WB, IDLE
            unique case (miss_state)
                LOAD: begin
                    wb_wen <= cresp.ready;
                    wb_offset <= miss_addr.offset;
                    // data has arrived. change target offset before next posedge
                    if(cresp.ready) begin
                        // offset'() is used to ensure the "wrap loop"
                        miss_addr.offset <= offset_t'(miss_addr.offset + `OFFSETBITS'b1);
                        miss_data_loaded[miss_addr.offset] <= '1;
                    end
                    if(cresp.last) begin
                        // writebuffer need to write? WRITE : NOWRITE
                        miss_state <= wb_meta.valid && wb_meta.dirty ? WRITEBACK : IDLE;
                        // prepare for writeback writebuffer
                        creq_addr.tag <= wb_tag;
                    end
                end
                WRITEBACK: begin
                    // lock write buffer
                    wb_wen <= 0;
                    if (cresp.ready) begin
                        miss_addr.offset <= offset_t'(miss_addr.offset + `OFFSETBITS'b1);
                    end
                    if (cresp.last) begin
                        // if there is a miss, and cbus transfer finished
                        if (fsm_to_miss) begin
                            miss_state <= LOAD;
                            creq_addr.tag <= req_addr.tag;
                            creq_addr.index <= req_addr.index;
                            creq_addr.offset <= req_addr.offset;
                            miss_addr.idx <= miss_idx;
                            miss_addr.index <= req_addr.index;
                            miss_addr.offset <= req_addr.offset;
                            miss_data_loaded <= '0;
                            // writebuffer
                            wb_meta <= metai[miss_idx];
                            wb_tag <= tags[miss_idx];
                        end else 
                            miss_state <= IDLE;
                    end
                end
                default: begin
                    //IDLE do nothing, so we put it in default
                end
            endcase

            // write writeback buffer
            if(wb_wen) begin
                writebuffer[wb_offset] <= miss_rdata;
            end

            // always_comb run in sequence, so this if must stay at the end of the block
            // if there is a miss; writeback's finished =/=> fsm_to_miss
            if (fsm_to_miss) begin
                miss_state <= LOAD;
                creq_addr.tag <= req_addr.tag;
                creq_addr.index <= req_addr.index;
                creq_addr.offset <= req_addr.offset;
                miss_addr.idx <= miss_idx;
                miss_addr.index <= req_addr.index;
                miss_addr.offset <= req_addr.offset;
                miss_data_loaded <= '0;
                // writebuffer
                wb_meta <= metai[miss_idx];
                wb_tag <= tags[miss_idx];
            end
        end
    end : cache_fsm

    // cbus, skip and not_skip. stupid but no bug
    assign creq_no_skip.addr = {{UNUSED_ADDR_WIDTH{1'b0}}, creq_addr.tag, creq_addr.index, creq_addr.offset, {ZEROS{1'b0}}};
    assign creq_no_skip.valid = miss_state != IDLE;
    assign creq_no_skip.is_write = miss_state == WRITEBACK;
    assign creq_no_skip.size = MSIZE8;
    assign creq_no_skip.strobe = miss_state == WRITEBACK ? '1 : '0;
    assign creq_no_skip.data = writebuffer[miss_addr.offset];
    assign creq_no_skip.len = MLEN16;
    assign creq_no_skip.burst = AXI_BURST_WRAP;

    assign creq_skip.addr = dreq.addr;
    assign creq_skip.valid = dreq.valid;
    assign creq_skip.is_write = dreq.strobe != 0;
    assign creq_skip.size = dreq.size;
    assign creq_skip.strobe = dreq.strobe;
    assign creq_skip.data = dreq.data;
    assign creq_skip.len = MLEN1;
    assign creq_skip.burst = AXI_BURST_FIXED;

    assign creq = skip ? creq_skip : creq_no_skip;

    assign dresp.addr_ok = skip ? cresp.ready : is_hit && is_miss_data_loaded;
    assign dresp.data_ok = skip ? cresp.last : dresp_data_ok && is_hit && is_miss_data_loaded;
    assign dresp.data = skip ? cresp.data : hit_rdata;

    // DATA
    RAM_TrueDualPort #(
        .ADDR_WIDTH(CACHE_ADDR_WIDTH),
        .DATA_WIDTH(CACHE_DATA_WIDTH),
        .BYTE_WIDTH(8),
        .READ_LATENCY(1)
    ) data_ram (
        .clk, 
        .en_1(fsm_to_hit),
        .addr_1(cache_addr),
        .strobe_1(dreq.strobe),
        .wdata_1(dreq.data),
        .rdata_1(hit_rdata),
        .en_2(1),
        .addr_2(miss_addr),
        .strobe_2(miss_strobe),
        .wdata_2(miss_wdata), // TODO
        .rdata_2(miss_rdata) // a place for writebuffer used in lab3
    );

`ifdef PRINT_MISS_RATE
    u128 all_; // count the num of branch instr
    u128 miss_cnt; // count hit 
    u32 counter;
    always_ff @(posedge clk) begin 
        if(reset) begin
            {all_, miss_cnt, counter} <= '0;
        end else begin
            if(dresp.data_ok && !skip) begin
                all_ <= all_ + 1;
            end
            if(fsm_to_miss) begin
                miss_cnt <= miss_cnt + 1;
            end
            counter <= counter + 1;
            if(counter[27]) begin
                $display("|miss_cnt:%d all resp cnt:%d|\n", miss_cnt, all_);
                counter <= '0;
            end
        end
    end
`endif 
    
`else

	typedef enum u2 {
		IDLE,
		FETCH,
		READY,
		FLUSH
	} state_t /* verilator public */;

	// typedefs
    typedef union packed {
        word_t data;
        u8 [7:0] lanes;
    } view_t;

    typedef u4 offset_t;

    // registers
    state_t    state /* verilator public_flat_rd */;
    dbus_req_t req;  // dreq is saved once addr_ok is asserted.
    offset_t   offset;

    // wires
    offset_t start;
    assign start = dreq.addr[6:3];

    // the RAM
    struct packed {
        logic    en;
        strobe_t strobe;
        word_t   wdata;
    } ram;
    word_t ram_rdata;

    always_comb
    unique case (state)
    FETCH: begin
        ram.en     = 1;
        ram.strobe = 8'b11111111;
        ram.wdata  = cresp.data;
    end

    READY: begin
        ram.en     = 1;
        ram.strobe = req.strobe;
        ram.wdata  = req.data;
    end

    default: ram = '0;
    endcase

    RAM_SinglePort #(
		.ADDR_WIDTH(4),
		.DATA_WIDTH(64),
		.BYTE_WIDTH(8),
		.READ_LATENCY(0)
	) ram_inst (
        .clk(clk), .en(ram.en),
        .addr(offset),
        .strobe(ram.strobe),
        .wdata(ram.wdata),
        .rdata(ram_rdata)
    );

    // DBus driver
    assign dresp.addr_ok = state == IDLE;
    assign dresp.data_ok = state == READY;
    assign dresp.data    = ram_rdata;

    // CBus driver
    assign creq.valid    = state == FETCH || state == FLUSH;
    assign creq.is_write = state == FLUSH;
    assign creq.size     = MSIZE8;
    assign creq.addr     = req.addr;
    assign creq.strobe   = 8'b11111111;
    assign creq.data     = ram_rdata;
    assign creq.len      = MLEN16;
	assign creq.burst	 = AXI_BURST_INCR;

    // the FSM
    always_ff @(posedge clk)
    if (~reset) begin
        unique case (state)
        IDLE: if (dreq.valid) begin
            state  <= FETCH;
            req    <= dreq;
            offset <= start;
        end

        FETCH: if (cresp.ready) begin
            state  <= cresp.last ? READY : FETCH;
            offset <= offset + 1;
        end

        READY: begin
            state  <= (|req.strobe) ? FLUSH : IDLE;
        end

        FLUSH: if (cresp.ready) begin
            state  <= cresp.last ? IDLE : FLUSH;
            offset <= offset + 1;
        end

        endcase
    end else begin
        state <= IDLE;
        {req, offset} <= '0;
    end

`endif

endmodule

`endif
