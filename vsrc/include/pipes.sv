`ifndef __PIPES_SV
`define __PIPES_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "pipeline/decode/decode_pkg.sv"
`else

`endif

package pipes;
    import common::*;
    import decode_pkg::*;
/* Define pipeline structures here */
	//  Group: Typedefs
    // fetch
    typedef enum logic {
        PCPLUS4 = 1'b0,
        PCJUMP
    } pcsrc_t;

    typedef enum logic {
        PCEN = 1'b0,
        PCHOLD
    } pchold_t;
    
    typedef struct packed {
        addr_t pc_o;
        u32 raw_instr;
        pcsrc_t predict_pcsrc;
    } fetch_data_t;

    // CSR
    typedef enum logic[2:0] { 
        E_NO_EXCEPT = 3'b0,
        E_INSTR_MISALIGN,
        E_INSTR_ILLEGAL,
        E_ECALL,
        E_LD_MISALIGN,
        E_SD_MISALIGN
    } except_name_t;

    typedef struct packed {
        logic is_except, csr_wen, is_mret;
        u5 zimm;
        u12 csr_name;
        except_name_t except_name;
    } csr_ctl_t;

    typedef struct packed {
        logic csr_write_to_reg_en;
        u64 csr_write_to_reg_data;
    } csr_write_to_reg_t;

    typedef struct packed {
        logic csr_pc_valid;
        addr_t pc_nxt;
    } csr_pc_nxt_t;

    // decode
    typedef enum logic {
        ALURESULT = 1'b0,
        MEMDATA = 1'b1
    } writeback_src_t;
    typedef struct packed {
        creg_addr_t writereg;
        word_t write_data;
        logic regwrite_en;
    } writeback_data_t;

    typedef enum logic [2:0] {
        NOTHING = 3'b0,
        B_BEQ,
        J_JAL,
        I_JALR,
        U_AUIPC
    } branchorjump_t;

    typedef enum logic {
        RD2 = 1'b0,
        IMM = 1'b1
    } alusrc_t;

    typedef struct packed {
        //fetch
        //ex
        alusrc_t alusrc;
        alufunc_t aluop;
        branchorjump_t bj;
        logic is_32instr;
        //mem
        logic memr_en, memw_en;
        msize_t msize;
        logic mem_unsigned;
        //writeback
        logic regwrite_en;
        writeback_src_t writeback_src;
     } control_t;

    // instr in decode  
    typedef struct packed {
        op_t op;
        creg_addr_t ra1, ra2, writereg;
        word_t imm; // the imm number is a part of instr
        control_t ctl;
    } instr_t;

    typedef struct packed {
        pcsrc_t pcsrc;
        addr_t pc_o;
        instr_t instr;
        word_t rd1, rd2;
        fetch_data_t pc_and_instr;
        csr_ctl_t csr_ctl;
    } decode_data_t;

    typedef struct packed {
        word_t rd1, rd2;
    } regfile_o_t;

    typedef struct packed {
        creg_addr_t ra1, ra2;
        // writeback_data_t writeback_data;
    } regfile_i_t;

    // execute
   typedef struct packed {
        addr_t pc_o;
        instr_t instr;
        word_t aluout;
        word_t memw_data;
        fetch_data_t pc_and_instr;
        csr_ctl_t csr_ctl;
   } execute_data_t;

    // memory
    typedef struct packed {
        addr_t pc_o;
        instr_t instr;
        word_t aluout, memr_data;
        fetch_data_t pc_and_instr;
        csr_ctl_t csr_ctl;
        word_t formatted_memw_data;
        strobe_t strobe;
    } memory_data_t;

    // writeback

    // used in previous so here commended
    // typedef enum logic {
    //     MEMDATA,
    //     ALURESULT
    // } writeback_src_t;

    // typedef struct packed {
    //     creg_addr_t writereg;
    //     word_t write_data;
    //     logic regwrite_en;
    // } writeback_data_t;
    //  Group: Parameters

    // hazard
    typedef struct packed {
        logic fd, de, em, mw;
    } regflush_en_t;
    typedef struct packed {
        logic pc;
        logic fd, de, em, mw;
    } regstall_en_t;

    // forward
    typedef enum logic [1:0] {
        // please note that all forward target is execute
        // the tag here means the data sourse, a/b is sca/srcb
        NOFORWARD,
        FORWARDM,
        FORWARDW,
        FORWARDM1
    } forward_type_t;

    typedef struct packed {
        forward_type_t forwardAD;
        forward_type_t forwardBD;
        forward_type_t forwardAE;
        forward_type_t forwardBE;
        // forward_type_t forwardSD; // for sd after ld
        // decode_data_t dataD_o;
        execute_data_t dataE_o;
        memory_data_t dataM_o;
        memory_data_t dataM1;
        writeback_data_t dataW;
    } forward_t;

    // bpb
   typedef struct packed {
       addr_t pc, target_pc;
       pcsrc_t pcsrc;
   } bp_result_t;

   // multi
   typedef logic[40:0] u41;
   typedef enum logic { 
       INIT,
       DOING
   } multicycle_state_t;

endpackage: pipes

`endif
