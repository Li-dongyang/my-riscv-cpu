`ifndef __DECODE_PKG_SV
`define __DECODE_PKG_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

`endif

package decode_pkg;
    import common::*;

/* Define instrucion decoding rules here */

    typedef enum logic [4:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLL,
        ALU_SLLW,
        ALU_SRA,
        ALU_SRL,
        ALU_SRAW,
        ALU_SRLW,
        ALU_SLT,
        ALU_SLTU,
        ALU_MULTICYCLE,
        ALU_CSR
    } alufunc_t;

    typedef enum logic [6:0] {
        UNDEFINED = 7'b0, // NOP, and invalid instr
        ADDI, XORI, ORI, ANDI, LUI,
        JAL, BEQ, LD, SD, ADD,
        SUB, AND, OR, XOR, AUIPC,
        JALR,
        BNE, BLT, BGE, BLTU, BGEU,
        SLTI, SLTIU, SLLI, SRLI, SRAI,
        SLL, SLT, SLTU, SRL, SRA,
        ADDIW, SLLIW, SRLIW, SRAIW, ADDW,
        SUBW, SLLW, SRLW, SRAW,
        LB, LH, LW, LBU, LHU,
        LWU, SB, SH, SW,
        MUL, DIV, DIVU, REM, REMU,
        MULW, DIVW, DIVUW, REMW, REMUW,
        CSRRC, CSRRCI, CSRRS, CSRRSI, CSRRW,
        CSRRWI, ECALL, MRET
    } op_t;

    /* parameter is here */
    // opcode 
    parameter f7 OP_ADDI = 7'b0010011;
    parameter f7 OP_XORI = 7'b0010011;
    parameter f7 OP_ORI  = 7'b0010011;
    parameter f7 OP_ANDI = 7'b0010011;
    parameter f7 OP_SLTI = 7'b0010011;
    parameter f7 OP_SLTIU = 7'b0010011;
    parameter f7 OP_SLLI = 7'b0010011;
    parameter f7 OP_SRLI = 7'b0010011; // f7
    parameter f7 OP_SRAI = 7'b0010011; // f7

    parameter f7 OP_ADD = 7'b0110011;
    parameter f7 OP_SUB = 7'b0110011;
    parameter f7 OP_AND = 7'b0110011;
    parameter f7 OP_OR  = 7'b0110011;
    parameter f7 OP_XOR = 7'b0110011;
    parameter f7 OP_SLL = 7'b0110011;
    parameter f7 OP_SLT = 7'b0110011;
    parameter f7 OP_SLTU = 7'b0110011;
    parameter f7 OP_SRL = 7'b0110011; // F7
    parameter f7 OP_SRA = 7'b0110011; // f7
    parameter f7 OP_MUL = 7'b0110011; // f3
    parameter f7 OP_DIV = 7'b0110011; // f3
    parameter f7 OP_DIVU = 7'b0110011; // f3
    parameter f7 OP_REM = 7'b0110011; // f3
    parameter f7 OP_REMU = 7'b0110011; // f3

    parameter f7 OP_JALR = 7'b1100111; // no f7

    parameter f7 OP_BEQ = 7'b1100011; // no f7
    parameter f7 OP_BNE = 7'b1100011; // no f7
    parameter f7 OP_BLT = 7'b1100011; // no f7
    parameter f7 OP_BGE = 7'b1100011; // no f7
    parameter f7 OP_BLTU = 7'b1100011; // no f7
    parameter f7 OP_BGEU = 7'b1100011; // no f7

    parameter f7 OP_LD = 7'b0000011; // no f7
    parameter f7 OP_LB = 7'b0000011; // no f7
    parameter f7 OP_LH = 7'b0000011; // no f7
    parameter f7 OP_LW = 7'b0000011; // no f7
    parameter f7 OP_LWU = 7'b0000011; // no f7
    parameter f7 OP_LHU = 7'b0000011; // no f7
    parameter f7 OP_LBU = 7'b0000011; // no f7

    parameter f7 OP_SD = 7'b0100011; // no f7
    parameter f7 OP_SB = 7'b0100011; // no f7
    parameter f7 OP_SH = 7'b0100011; // no f7
    parameter f7 OP_SW = 7'b0100011; // no f7
    
    parameter f7 OP_LUI = 7'b0110111; // no f7 f3

    parameter f7 OP_AUIPC = 7'b0010111; // no f7 f3

    parameter f7 OP_JAL = 7'b1101111; // no f7 f3

    parameter f7 OP_ADDIW = 7'b0011011; // no f7
    parameter f7 OP_SLLIW = 7'b0011011; // no f7
    parameter f7 OP_SRLIW = 7'b0011011; // f7
    parameter f7 OP_SRAIW = 7'b0011011; // f7

    parameter f7 OP_ADDW = 7'b0111011; // f7
    parameter f7 OP_SUBW = 7'b0111011; // f7
    parameter f7 OP_SLLW = 7'b0111011; // no f7
    parameter f7 OP_SRLW = 7'b0111011; // f7
    parameter f7 OP_SRAW = 7'b0111011; // f7
    parameter f7 OP_DIVW = 7'b0111011; // f7
    parameter f7 OP_MULW = 7'b0111011; // f7
    parameter f7 OP_DIVUW = 7'b0111011; // f7
    parameter f7 OP_REMW = 7'b0111011; // f7
    parameter f7 OP_REMUW = 7'b0111011; // f7

    parameter f7 OP_CSRRC = 7'b1110011; // no f7
    parameter f7 OP_CSRRCI = 7'b1110011; // no f7
    parameter f7 OP_CSRRS = 7'b1110011; // no f7
    parameter f7 OP_CSRRSI = 7'b1110011; // no f7
    parameter f7 OP_CSRRW = 7'b1110011; // no f7
    parameter f7 OP_CSRRWI = 7'b1110011; // no f7
    parameter f7 OP_ECALL = 7'b1110011; // f7
    parameter f7 OP_MRET = 7'b1110011; // f7

    // f7 --------------------------------------
    parameter f7 F7_ADD = 7'b0000000;
    parameter f7 F7_SUB = 7'b0100000; //!
    parameter f7 F7_AND = 7'b0000000;
    parameter f7 F7_OR  = 7'b0000000;
    parameter f7 F7_XOR = 7'b0000000;
    parameter f7 F7_ADDW = 7'b0000000;
    parameter f7 F7_SUBW = 7'b0100000; //!

    parameter f7 F7_SRLI = 7'b0000000;
    parameter f7 F7_SRAI = 7'b0100000; //!
    parameter f7 F7_SRLIW = 7'b0000000;
    parameter f7 F7_SRAIW = 7'b0100000; //!

    parameter f7 F7_SRL = 7'b0000000;
    parameter f7 F7_SRA = 7'b0100000; //!
    parameter f7 F7_SRLW = 7'b0000000;
    parameter f7 F7_SRAW = 7'b0100000; //!

    parameter f7 F7_MUL = 7'b0000001;
    parameter f7 F7_DIV = 7'b0000001;
    parameter f7 F7_DIVU = 7'b0000001;
    parameter f7 F7_REM = 7'b0000001;
    parameter f7 F7_REMU = 7'b0000001;
    parameter f7 F7_REMWU = 7'b0000001;
    parameter f7 F7_REMW = 7'b0000001;
    parameter f7 F7_DIVUW = 7'b0000001;
    parameter f7 F7_DIVW = 7'b0000001;
    parameter f7 F7_MULW = 7'b0000001;

    parameter f7 F7_ECALL = 7'b0000000;
    parameter f7 F7_MRET = 7'b0011000;

    // f3 ---------------------------------------
    parameter f3 F3_ADDI = 3'b000;
    parameter f3 F3_XORI = 3'b100;
    parameter f3 F3_ORI  = 3'b110;
    parameter f3 F3_ANDI = 3'b111;
    parameter f3 F3_SLTI = 3'b010;
    parameter f3 F3_SLTIU = 3'b011;
    parameter f3 F3_SLLI = 3'b001; 
    parameter f3 F3_SRLI = 3'b101;
    parameter f3 F3_SRAI = 3'b101;

    parameter f3 F3_ADD  = 3'b000;
    parameter f3 F3_SUB  = 3'b000;
    parameter f3 F3_AND  = 3'b111;
    parameter f3 F3_OR   = 3'b110;
    parameter f3 F3_XOR  = 3'b100;
    parameter f3 F3_SLL = 3'b001;
    parameter f3 F3_SLT = 3'b010;
    parameter f3 F3_SLTU = 3'b011;
    parameter f3 F3_SRL = 3'b101;
    parameter f3 F3_SRA = 3'b101;
    parameter f3 F3_MUL = 3'b000;
    parameter f3 F3_DIV = 3'b100;
    parameter f3 F3_DIVU = 3'b101;
    parameter f3 F3_REM = 3'b110;
    parameter f3 F3_REMU = 3'b111;

    parameter f3 F3_JALR = 3'b000;

    parameter f3 F3_BEQ = 3'b000;
    parameter f3 F3_BNE = 3'b001;
    parameter f3 F3_BLT = 3'b100;
    parameter f3 F3_BGE = 3'b101;
    parameter f3 F3_BLTU = 3'b110;
    parameter f3 F3_BGEU = 3'b111;

    parameter f3 F3_ADDIW = 3'b000;
    parameter f3 F3_SLLIW = 3'b001;
    parameter f3 F3_SRLIW = 3'b101;
    parameter f3 F3_SRAIW = 3'b101;

    parameter f3 F3_ADDW = 3'b000;
    parameter f3 F3_SUBW = 3'b000;
    parameter f3 F3_SLLW = 3'b001;
    parameter f3 F3_SRLW = 3'b101;
    parameter f3 F3_SRAW = 3'b101;
    parameter f3 F3_MULW = 3'b000;
    parameter f3 F3_DIVW = 3'b100;
    parameter f3 F3_DIVUW = 3'b101;
    parameter f3 F3_REMW = 3'b110;
    parameter f3 F3_REMUW = 3'b111;

    parameter f3 F3_LD = 3'b011;
    parameter f3 F3_LB = 3'b000;
    parameter f3 F3_LH = 3'b001;
    parameter f3 F3_LW = 3'b010;
    parameter f3 F3_LWU = 3'b110;
    parameter f3 F3_LHU = 3'b101;
    parameter f3 F3_LBU = 3'b100;

    parameter f3 F3_SD = 3'b011;
    parameter f3 F3_SB = 3'b000;
    parameter f3 F3_SH = 3'b001;
    parameter f3 F3_SW = 3'b010;

    parameter f3 F3_ECALL = 3'b000;
    parameter f3 F3_MRET = 3'b000;
    parameter f3 F3_CSRRC = 3'b011;
    parameter f3 F3_CSRRCI = 3'b111;
    parameter f3 F3_CSRRS = 3'b010;
    parameter f3 F3_CSRRSI = 3'b110;
    parameter f3 F3_CSRRW = 3'b001;
    parameter f3 F3_CSRRWI = 3'b101;
endpackage: decode_pkg
`endif 