`ifndef __DECODER_SV
`define __DECODER_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/decode/decode_pkg.sv"
`else

`endif

module decoder
    import common::*;
    import pipes::*;
    import decode_pkg::*;(
	input u32 raw_instr,
    // PIPELINE
    output instr_t instr,
    output csr_ctl_t csr_ctl
);
    f7 op = raw_instr[6:0];
    f3 F3 = raw_instr[14:12];
    f7 F7 = raw_instr[31:25];

    creg_addr_t ra1, ra2, writereg;
    assign ra1 = raw_instr[19:15];
    assign ra2 = raw_instr[24:20];
    assign writereg = raw_instr[11:7];
    control_t ctl;
    assign instr.ctl = ctl;
    
    always_comb begin : decoder
        {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
        unique case (op)
            OP_ADDI: begin
                unique case (F3)
                    F3_ADDI:  begin
                        instr.op = ADDI;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        instr.imm = {{52{raw_instr[31]}}, raw_instr[31:20]};
                        ctl.alusrc = IMM;
                        ctl.aluop = ALU_ADD;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_XORI: begin
                        instr.op = XORI;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        instr.imm = {{52{raw_instr[31]}}, raw_instr[31:20]};
                        ctl.alusrc = IMM;
                        ctl.aluop = ALU_XOR;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_ORI: begin
                        instr.op = ORI;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        instr.imm = {{52{raw_instr[31]}}, raw_instr[31:20]};
                        ctl.alusrc = IMM;
                        ctl.aluop = ALU_OR;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_ANDI: begin
                        instr.op = ANDI;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        instr.imm = {{52{raw_instr[31]}}, raw_instr[31:20]};
                        ctl.alusrc = IMM;
                        ctl.aluop = ALU_AND;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SLTI: begin
                        instr.op = SLTI;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        instr.imm = {{52{raw_instr[31]}}, raw_instr[31:20]};
                        ctl.alusrc = IMM;
                        ctl.aluop = ALU_SLT;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SLTIU: begin
                        instr.op = SLTIU;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        instr.imm = {{52{raw_instr[31]}}, raw_instr[31:20]};
                        ctl.alusrc = IMM;
                        ctl.aluop = ALU_SLTU;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SLLI: begin
                        instr.op = SLLI;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        instr.imm = {58'b0, F7[0], ra2};
                        ctl.alusrc = IMM;
                        ctl.aluop = ALU_SLL;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SRLI: begin
                        unique case ({F7[6:1], 1'b0})
                            F7_SRLI: begin
                                instr.op = SRLI;
                                instr.ra1 = ra1;
                                instr.writereg = writereg;
                                instr.imm = {58'b0, F7[0], ra2};
                                ctl.alusrc = IMM;
                                ctl.aluop = ALU_SRL;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_SRAI: begin
                                instr.op = SRAI;
                                instr.ra1 = ra1;
                                instr.writereg = writereg;
                                instr.imm = {58'b0, F7[0], ra2};
                                ctl.alusrc = IMM;
                                ctl.aluop = ALU_SRA;
                                ctl.regwrite_en = 1'b1;
                            end
                            default:
                            {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                        endcase
                    end
                    default: begin
                        {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                    end
                endcase
            end
            OP_ADD:
                unique case (F3)
                    F3_ADD:  begin
                        unique case (F7)
                            F7_ADD: begin
                                instr.op = ADD;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.alusrc = RD2;
                                ctl.aluop = ALU_ADD;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_SUB: begin
                                instr.op = SUB;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.alusrc = RD2;
                                ctl.aluop = ALU_SUB;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_MUL: begin
                                instr.op = MUL;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.alusrc = RD2;
                                ctl.aluop = ALU_MULTICYCLE;
                                ctl.regwrite_en = 1'b1;
                            end
                            default: 
                                {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                        endcase
                    end
                    F3_AND: begin
                        unique case (F7)
                            F7_ADD: begin
                                instr.op = AND;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.aluop = ALU_AND;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_REMU: begin
                                instr.op = REMU;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.aluop = ALU_MULTICYCLE;
                                ctl.regwrite_en = 1'b1;
                            end
                            default: 
                                {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                        endcase
                    end 
                    F3_XOR: begin
                        unique case (F7)
                            F7_XOR: begin 
                                instr.op = XOR;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.aluop = ALU_XOR;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_DIV: begin
                                instr.op = DIV;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.aluop = ALU_MULTICYCLE;
                                ctl.regwrite_en = 1'b1;
                            end
                            default: 
                                {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                        endcase
                    end
                    F3_OR: begin
                        unique case (F7)
                            F7_OR : begin
                                instr.op = OR;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.aluop = ALU_OR;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_REM: begin
                                instr.op = REM;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.aluop = ALU_MULTICYCLE;
                                ctl.regwrite_en = 1'b1;
                            end
                            default: 
                                {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                        endcase
                    end 
                    F3_SLL: begin
                        instr.op = SLL;
                        instr.ra1 = ra1;
                        instr.ra2 = ra2;
                        instr.writereg = writereg;
                        ctl.aluop = ALU_SLL;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SLT: begin
                        instr.op = SLT;
                        instr.ra1 = ra1;
                        instr.ra2 = ra2;
                        instr.writereg = writereg;
                        ctl.aluop = ALU_SLT;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SLTU: begin
                        instr.op = SLTU;
                        instr.ra1 = ra1;
                        instr.ra2 = ra2;
                        instr.writereg = writereg;
                        ctl.aluop = ALU_SLTU;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SRL: begin
                        unique case (F7)
                            F7_SRL: begin
                                instr.op = SRL;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.aluop = ALU_SRL;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_SRA: begin
                                instr.op = SRA;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.aluop = ALU_SRA;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_DIVU: begin
                                instr.op = DIVU;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                instr.writereg = writereg;
                                ctl.aluop = ALU_MULTICYCLE;
                                ctl.regwrite_en = 1'b1;
                            end
                            default:
                            {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                        endcase
                    end
                    default: begin
                        {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                    end
                endcase
            OP_JALR: begin
                instr.op = JALR;
                instr.ra1 = ra1;
                instr.writereg = writereg;
                instr.imm = {{52{raw_instr[31]}}, raw_instr[31:20]};
                ctl.alusrc = IMM;
                ctl.aluop = ALU_ADD;
                ctl.bj = I_JALR;
                ctl.regwrite_en = 1'b1;
            end
            OP_BEQ: begin
                instr.ra1 = ra1;
                instr.ra2 = ra2;
                instr.imm = {{52{raw_instr[31]}}, raw_instr[7:7], raw_instr[30:25], raw_instr[11:8], 1'b0};
                ctl.alusrc = IMM;
                ctl.aluop = ALU_ADD;
                ctl.bj = B_BEQ;
                unique case (F3)
                    F3_BEQ: begin
                        instr.op = BEQ;
                    end
                    F3_BNE: begin
                        instr.op = BNE;
                    end
                    F3_BLT: begin
                        instr.op = BLT;
                    end
                    F3_BGE: begin
                        instr.op = BGE;
                    end
                    F3_BLTU: begin
                        instr.op = BLTU;
                    end
                    F3_BGEU: begin
                        instr.op = BGEU;
                    end
                    default:
                        {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                endcase
            end
            OP_LD: begin
                instr.ra1 = ra1;
                instr.writereg = writereg;
                instr.imm = {{52{raw_instr[31]}}, raw_instr[31:20]};
                ctl.alusrc = IMM;
                ctl.aluop = ALU_ADD;
                ctl.memr_en = 1'b1;
                ctl.regwrite_en = 1'b1;
                ctl.writeback_src = MEMDATA;
                unique case (F3)
                    F3_LD: begin
                        instr.op = LD;
                        ctl.msize = MSIZE8;
                    end
                    F3_LB: begin
                        instr.op = LB;
                        ctl.msize = MSIZE1;
                    end
                    F3_LH: begin
                        instr.op = LH;
                        ctl.msize = MSIZE2;
                    end
                    F3_LW: begin
                        instr.op = LW;
                        ctl.msize = MSIZE4;
                    end
                    F3_LBU: begin
                        instr.op = LBU;
                        ctl.msize = MSIZE1;
                        ctl.mem_unsigned = 1'b1;
                    end
                    F3_LHU:  begin
                        instr.op = LHU;
                        ctl.msize = MSIZE2;
                        ctl.mem_unsigned = 1'b1;
                    end
                    F3_LWU:  begin
                        instr.op = LWU;
                        ctl.msize = MSIZE4;
                        ctl.mem_unsigned = 1'b1;
                    end
                    default:
                        {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                endcase
            end
            OP_SD: begin
                instr.ra1 = ra1;
                instr.ra2 = ra2;
                instr.imm = {{52{raw_instr[31]}}, raw_instr[31:25], raw_instr[11:7]};
                ctl.alusrc = IMM;
                ctl.aluop = ALU_ADD;
                ctl.memw_en = 1'b1;
                unique case (F3)
                    F3_SB: begin
                        instr.op = SB;
                        ctl.msize = MSIZE1;
                    end
                    F3_SH: begin
                        instr.op = SH;
                        ctl.msize = MSIZE2;
                    end
                    F3_SW: begin
                        instr.op = SW;
                        ctl.msize = MSIZE4;
                    end
                    F3_SD: begin
                        instr.op = SD;
                        ctl.msize = MSIZE8;
                    end
                    default:
                        {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                endcase
            end
            OP_LUI: begin
                instr.op = LUI;
                instr.ra1 = 5'b0;
                instr.writereg = writereg;
                instr.imm = {{32{raw_instr[31]}}, raw_instr[31:12], 12'b0};
                ctl.alusrc = IMM;
                ctl.aluop = ALU_ADD;
                ctl.regwrite_en = 1'b1;
            end
            OP_AUIPC: begin
                instr.op = AUIPC;
                instr.ra1 = 5'b0;
                instr.writereg = writereg;
                instr.imm = {{32{raw_instr[31]}}, raw_instr[31:12], 12'b0};
                ctl.alusrc = IMM;
                ctl.aluop = ALU_ADD;
                ctl.bj = U_AUIPC;
                ctl.regwrite_en = 1'b1;
            end
            OP_JAL: begin
                instr.op = JAL;
                instr.ra1 = 5'b0;
                instr.writereg = writereg;
                instr.imm = {{44{raw_instr[31]}}, raw_instr[19:12], raw_instr[20:20], raw_instr[30:21], 1'b0};
                ctl.alusrc = IMM;
                ctl.aluop = ALU_ADD;
                ctl.bj = J_JAL;
                ctl.regwrite_en = 1'b1;
            end
            OP_ADDIW: begin
                ctl.is_32instr = 1'b1;
                instr.writereg = writereg;
                unique case (F3)
                    F3_ADDIW: begin
                        instr.op = ADDIW;
                        instr.ra1 = ra1;
                        instr.imm = {{52{raw_instr[31]}}, raw_instr[31:20]};
                        ctl.alusrc = IMM;
                        ctl.aluop = ALU_ADD;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SLLIW: begin
                        instr.op = SLLIW;
                        instr.ra1 = ra1;
                        instr.imm = {59'b0, ra2};
                        ctl.alusrc = IMM;
                        ctl.aluop = ALU_SLLW;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SRLIW: begin
                        unique case (F7)
                            F7_SRLIW: begin
                                instr.op = SRLIW;
                                instr.ra1 = ra1;
                                instr.imm = {59'b0, ra2};
                                ctl.alusrc = IMM;
                                ctl.aluop = ALU_SRLW;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_SRAIW: begin
                                instr.op = SRAIW;
                                instr.ra1 = ra1;
                                instr.imm = {59'b0, ra2};
                                ctl.alusrc = IMM;
                                ctl.aluop = ALU_SRAW;
                                ctl.regwrite_en = 1'b1;
                            end
                            default:
                            {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                        endcase
                    end
                    default: begin
                        {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                    end
                endcase
            end
            OP_ADDW: begin
                ctl.is_32instr = 1'b1;
                instr.writereg = writereg;
                unique case (F3)
                    F3_ADDW:
                        unique case (F7)
                            F7_ADDW: begin
                                instr.op = ADDW;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                ctl.aluop = ALU_ADD;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_SUBW: begin
                                instr.op = SUBW;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                ctl.aluop = ALU_SUB;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_MULW: begin
                                instr.op = MULW;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                ctl.aluop = ALU_MULTICYCLE;
                                ctl.regwrite_en = 1'b1;
                            end
                            default:
                                {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                        endcase
                    F3_SLLW: begin
                        instr.op = SLLW;
                        instr.ra1 = ra1;
                        instr.ra2 = ra2;
                        ctl.aluop = ALU_SLLW;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_DIVW: begin
                        instr.op = DIVW;
                        instr.ra1 = ra1;
                        instr.ra2 = ra2;
                        ctl.aluop = ALU_MULTICYCLE;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_SRLW: begin
                        unique case (F7)
                            F7_SRLW: begin
                                instr.op = SRLW;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                ctl.aluop = ALU_SRLW;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_SRAW: begin
                                instr.op = SRAIW;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                ctl.aluop = ALU_SRAW;
                                ctl.regwrite_en = 1'b1;
                            end
                            F7_DIVUW: begin
                                instr.op = DIVUW;
                                instr.ra1 = ra1;
                                instr.ra2 = ra2;
                                ctl.aluop = ALU_MULTICYCLE;
                                ctl.regwrite_en = 1'b1;
                            end
                            default:
                                {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                        endcase
                    end
                    F3_REMW: begin
                        instr.op = REMW;
                        instr.ra1 = ra1;
                        instr.ra2 = ra2;
                        ctl.aluop = ALU_MULTICYCLE;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_REMUW: begin
                        instr.op = REMUW;
                        instr.ra1 = ra1;
                        instr.ra2 = ra2;
                        ctl.aluop = ALU_MULTICYCLE;
                        ctl.regwrite_en = 1'b1;
                    end
                    default: begin
                        {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                    end
                    endcase
                end  
            OP_CSRRC: begin
                instr.ra2 = '0;
                csr_ctl.csr_wen = 1'b1;
                csr_ctl.csr_name = raw_instr[31:20];
                unique case (F3)
                    F3_CSRRC: begin
                        instr.op = CSRRC;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        ctl.aluop = ALU_CSR;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_CSRRCI: begin
                        instr.op = CSRRCI;
                        instr.ra1 = '0;
                        instr.writereg = writereg;
                        ctl.aluop = ALU_CSR;
                        ctl.regwrite_en = 1'b1;
                        csr_ctl.zimm = raw_instr[19:15];
                    end
                    F3_CSRRS: begin
                        instr.op = CSRRS;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        ctl.aluop = ALU_CSR;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_CSRRSI: begin
                        instr.op = CSRRSI;
                        instr.ra1 = '0;
                        instr.writereg = writereg;
                        ctl.aluop = ALU_CSR;
                        ctl.regwrite_en = 1'b1;
                        csr_ctl.zimm = raw_instr[19:15];
                    end
                    F3_CSRRW: begin
                        instr.op = CSRRW;
                        instr.ra1 = ra1;
                        instr.writereg = writereg;
                        ctl.aluop = ALU_CSR;
                        ctl.regwrite_en = 1'b1;
                    end
                    F3_CSRRWI: begin
                        instr.op = CSRRWI;
                        instr.ra1 = '0;
                        instr.writereg = writereg;
                        ctl.aluop = ALU_CSR;
                        ctl.regwrite_en = 1'b1;
                        csr_ctl.zimm = raw_instr[19:15];
                    end
                    F3_ECALL:begin
                        unique case (F7)
                            F7_ECALL: begin
                                instr.op = ECALL;
                                instr.ra1 = '0;
                                ctl.aluop = ALU_CSR;
                                csr_ctl.is_except = 1'b1;
                                csr_ctl.except_name = E_ECALL;
                            end
                            F7_MRET: begin
                                instr.op = MRET;
                                instr.ra1 = '0;
                                ctl.aluop = ALU_CSR;
                                csr_ctl.is_mret = 1'b1;
                            end
                            default: begin
                                {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                            end   
                        endcase
                    end
                    default: begin
                        {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, csr_ctl, ctl} = '0;
                    end   
                endcase
            end
            default: begin
                {instr.op, instr.ra1, instr.ra2, instr.writereg, instr.imm, ctl, csr_ctl} = '0;
            end    
        endcase
    end
endmodule
`endif 