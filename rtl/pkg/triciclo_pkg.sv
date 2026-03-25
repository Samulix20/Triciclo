package triciclo_pkg;
/* verilator lint_off UNUSEDPARAM */

// Utility functions for parameters
function int clamp0 (int v);
    if (v < 0) return 0;
    else return v;
endfunction

// RISC-V Specific definitions

typedef logic [4:0] rv_reg_id_t;
typedef logic [11:0] rv_csr_id_t;

// Decoding defaults to R-Type
typedef struct packed {
    logic [6:0] funct7;     // [31:25]
    rv_reg_id_t rs2;        // [24:20]
    rv_reg_id_t rs1;        // [19:15]
    logic [2:0] funct3;     // [14:12]
    rv_reg_id_t rd;         // [11:07]
    logic [6:0] opcode;     // [06:00]
} rv_instr_t /*verilator public*/;

typedef struct packed {
    rv_reg_id_t rs3;
    logic [1:0] fmt;
    rv_reg_id_t rs2;
    rv_reg_id_t rs1;
    logic [2:0] rm;
    rv_reg_id_t rd;
    logic [6:0] opcode;
} rv_r4_instr_t /*verilator public*/;

// Nop operation add x0 x0, 0 (0x00000033)
parameter rv_instr_t RV_NOP = 'h33;

/* verilator lint_off UNUSEDSIGNAL */
// Imediate generation functions
function automatic logic[31:0] decode_i_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:11] = '{default: instr[31]};
    imm[10:0] = instr[30:20];
    return imm;
endfunction

function automatic logic[31:0] decode_s_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:11] = '{default: instr[31]};
    imm[10:5] = instr[30:25];
    imm[4:0] = instr[11:7];
    return imm;
endfunction

function automatic logic[31:0] decode_b_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:12] = '{default: instr[31]};
    imm[11] = instr[7];
    imm[10:5] = instr[30:25];
    imm[4:1] = instr[11:8];
    imm[0] = 0;
    return imm;
endfunction

function automatic logic[31:0] decode_u_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:12] = instr[31:12];
    imm[11:0] = '{default: 0};
    return imm;
endfunction

function automatic logic[31:0] decode_j_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:20] = '{default: instr[31]};
    imm[19:12] = instr[19:12];
    imm[11] = instr[20];
    imm[10:1] = instr[30:21];
    imm[0] = 0;
    return imm;
endfunction
/* verilator lint_on UNUSEDSIGNAL */

typedef enum logic [6:0] {
    OPCODE_LUI = 7'b0110111,
    OPCODE_AUIPC = 7'b0010111,
    OPCODE_JAL = 7'b1101111,
    OPCODE_JALR = 7'b1100111,
    OPCODE_BRANCH = 7'b1100011,
    OPCODE_LOAD = 7'b0000011,
    OPCODE_STORE = 7'b0100011,
    OPCODE_INTEGER_IMM = 7'b0010011,
    OPCODE_INTEGER_REG = 7'b0110011,
    OPCODE_BARRIER = 7'b0001111,
    OPCODE_SYSTEM = 7'b1110011,
    OPCODE_AMO = 7'b0101111,
    OPCODE_CUSTOM_0 = 7'b0001011,
    OPCODE_CUSTOM_1 = 7'b0101011,
    OPCODE_CUSTOM_2 = 7'b1011011,
    OPCODE_CUSTOM_3 = 7'b1111011
} valid_opcodes_t /*verilator public*/;

// Global CSR register formats

// CSR LIST
typedef enum logic [11:0] {
    CSR_MSTATUS = 'h300,
    CSR_MISA = 'h301,
    // Machine
    CSR_MEDELEG = 'h302,
    CSR_MIDELEG = 'h303,
    CSR_MIE = 'h304,
    CSR_MTVEC = 'h305,
    CSR_MSCRATCH = 'h340,
    CSR_MEPC = 'h341,
    CSR_MCAUSE = 'h342,
    CSR_MTVAL = 'h343,
    // Supervisor
    CSR_SSTATUS = 'h100,
    CSR_SIE = 'h104,
    CSR_STVEC = 'h105,
    CSR_SEPC = 'h141,
    CSR_SCAUSE = 'h142,
    CSR_STVAL = 'h143,
    // "Real" Machine hardware counters
    CSR_MCOUNTINHIBIT = 'h320,
    CSR_MCYCLE = 'hB00,
    CSR_MCYCLEH = 'hB80,
    CSR_MINSTRET = 'hB02,
    CSR_MINSTRETH = 'hB82,
    // Aliases for Zinctr extension
    CSR_CYCLE = 'hC00,
    CSR_CYCLEH = 'hC80,
    CSR_TIME = 'hC01,
    CSR_TIMEH = 'hC81,
    CSR_INSTRET = 'hC02,
    CSR_INSTRETH = 'hC82,
    // IDs
    CSR_MHARTID = 'hF14
} rv_valid_csr_t;

typedef enum logic [1:0] {
    MODE_USER = 'b00,
    MODE_SUPERVISOR = 'b01,
    MODE_MACHINE = 'b11
} priv_mode_t;

typedef struct packed {
    priv_mode_t mpp; // 10:9
    logic spp;       // 8
    logic mpie;      // 7
    logic spie;      // 5
    logic mie;       // 3
    logic sie;       // 1
} mstatus_t;

typedef struct packed {
    logic mtip;
    logic msip;
    logic meip;
} mip_t;

typedef struct packed {
    logic meie; // 11
    logic mtie; // 7
    logic msie; // 3
} mie_t;

typedef struct packed {
    logic tip;
    logic sip;
    logic eip;
} mideleg_t;

typedef struct packed {
    logic m_ecall;
    logic s_ecall;
    logic u_ecall;
    logic st_ma;
    logic ld_ma;
    logic breakpoint;
    logic illegal_instr;
    logic instr_ma;
} medeleg_t;

typedef struct packed {
    logic stip;
    logic ssip;
    logic seip;
} sip_t;

typedef struct packed {
    logic stie;
    logic ssie;
    logic seie;
} sie_t;

typedef enum logic [31:0] {
    CAUSE_MISALIGNED_FETCH = 'h0,
    CAUSE_ILLEGAL_INSTRUCTION = 'h2,
    CAUSE_BREAKPOINT = 'h3,
    CAUSE_MISALIGNED_LOAD = 'h4,
    CAUSE_MISALIGNED_STORE = 'h6,
    CAUSE_USER_ECALL = 'h8,
    CAUSE_SUPERVISOR_ECALL = 'h9,
    CAUSE_MACHINE_ECALL = 'hb,
    CAUSE_SOFT_IRQ = 'h80000003,
    CAUSE_TIMER_IRQ = 'h80000007,
    CAUSE_EXT_IRQ  = 'h8000000B
} trap_cause_t;


// Core Config

// Register file num outputs
localparam int unsigned CORE_RF_NUM_READ /*verilator public*/ = 2;

// Definitions for all data types, structs, etc...
typedef logic[31:0] l32;
typedef l32 [1:0] l64;

localparam l32 RESET_PC = 'h80000000;

typedef enum logic [2:0] {
    IMM_0,
    IMM_I,
    IMM_S,
    IMM_B,
    IMM_U,
    IMM_J
} imm_t /*verilator public*/;

// SLT set less than
// SLL shift left logical
// SRL shift right logical
// SRA shift right arithmetic
typedef enum logic [3:0] {
    ALU_OP_ADD  = 4'b0000,
    ALU_OP_SLL  = 4'b0001,
    ALU_OP_SLT  = 4'b0010,
    ALU_OP_SLTU = 4'b0011,
    ALU_OP_XOR  = 4'b0100,
    ALU_OP_SRL  = 4'b0101,
    ALU_OP_OR   = 4'b0110,
    ALU_OP_AND  = 4'b0111,
    ALU_OP_SUB  = 4'b1000,
    ALU_OP_SRA  = 4'b1101
} int_alu_op_t /*verilator public*/;

typedef enum logic[1:0] {
    ALU_IN_PC_IMM,
    ALU_IN_R1_IMM,
    ALU_IN_R1_R2
} int_alu_input_t /*verilator public*/;

// Mul operations
typedef enum logic [1:0] {
    MUL_OP_MUL    = 2'b00,
    MUL_OP_MULH   = 2'b01,
    MUL_OP_MULHSU = 2'b10,
    MUL_OP_MULHU  = 2'b11
} mul_op_t /*verilator public*/;

/* verilator lint_off UNUSEDSIGNAL */
function automatic mul_op_t get_mul_op(input rv_instr_t instr);
    return mul_op_t'(instr.funct3[1:0]);
endfunction
/* verilator lint_on UNUSEDSIGNAL */

// Zicsr operations
typedef enum logic [1:0] {
    CSR_NOP = 2'b00,
    CSR_RW = 2'b01,
    CSR_RS = 2'b10,
    CSR_RC = 2'b11
} zicsr_op_t /*verilator public*/;

typedef enum logic [3:0] {
    OP_BEQ = 4'b0000,
    OP_BNE = 4'b0001,
    OP_BLT = 4'b0100,
    OP_BGE = 4'b0101,
    OP_BLTU = 4'b0110,
    OP_BGEU = 4'b0111,
    OP_J = 4'b1000,
    OP_NOP = 4'b1111
} branch_op_t /*verilator public*/;

typedef enum logic [3:0] {
    MEM_LB = 4'b0000,
    MEM_LH = 4'b0001,
    MEM_LW = 4'b0010,
    MEM_LBU = 4'b0100,
    MEM_LHU = 4'b0101,
    MEM_SB = 4'b1000,
    MEM_SH = 4'b1001,
    MEM_SW = 4'b1010,
    MEM_NOP = 4'b1111
} mem_op_t /*verilator public*/;

/* verilator lint_off UNUSEDSIGNAL */
function automatic logic is_mem_store(input mem_op_t op);
    return op[3];
endfunction
/* verilator lint_on UNUSEDSIGNAL */

typedef enum logic [1:0] {
    AMO_NOP,
    AMO_LR,
    AMO_SC
} amo_op_t;

typedef enum logic [2:0] {
    // Standard outputs
    WB_IMM,
    WB_ALU,
    WB_PC4,
    WB_MUL,
    WB_LOAD,
    WB_STORE,
    WB_CSR
} wb_result_t /*verilator public*/;

typedef enum logic [3:0] {
    NO_TRAP,
    TRAP_IRQ,
    TRAP_ILLEGAL,
    TRAP_MISALIGNED_FETCH,
    TRAP_MISALIGNED_LOAD,
    TRAP_MISALIGNED_STORE,
    TRAP_ECALL,
    TRAP_EBREAK,
    TRAP_MRET,
    TRAP_SRET
} trap_type_t;

typedef struct packed {
    // Is bubble
    logic bubble;
    // Immediate generation
    imm_t imm;
    // Branch
    branch_op_t branch_op;
    // Int Alu
    int_alu_op_t int_alu_op;
    int_alu_input_t int_alu_input;
    // Memory
    mem_op_t mem_op;
    // Writeback source
    wb_result_t wb_result_src;
    // Final Writeback
    logic rf_write;
    // Final CSR write
    logic csr_write;
    // Trap / Exception detection
    trap_type_t trap_type;
    // Atomic operations
    amo_op_t amo_op;
} control_t /*verilator public*/;

// Used for NOP generation
function automatic control_t create_nop_ctrl();
    control_t instr;
    instr.bubble = 1;
    instr.imm = IMM_0;
    instr.branch_op = OP_NOP;
    instr.int_alu_op = ALU_OP_ADD;
    instr.int_alu_input = ALU_IN_R1_R2;
    instr.mem_op = MEM_NOP;
    instr.amo_op = AMO_NOP;
    instr.wb_result_src = WB_ALU;
    instr.rf_write = 0;
    instr.csr_write = 0;
    instr.trap_type = NO_TRAP;

    return instr;
endfunction

typedef enum logic [1:0] {
    NO_FLUSH,
    FLUSH_BRANCH,
    FLUSH_TRAP
} flush_type_t;

typedef struct packed {
    mstatus_t mstatus;
    mie_t mie;
    l32 mtvec;
    l32 mepc;
} trap_config_t;

typedef struct packed {
    logic write_enable;
    rv_csr_id_t id;
    l32 data;
} csr_write_request_t /*verilator public*/;

typedef struct packed {
    flush_type_t op;
    l32 from;
    l32 to;
    l32 cause;
    l32 value;
} flush_bus_t /*verilator public*/;

typedef struct packed {
    logic write_enable;
    rv_reg_id_t id;
    l32 data;
} rf_write_request_t /*verilator public*/;

typedef struct packed {
    l32 addr;
    l32 data;
    mem_op_t op;
} mem_request_t /*verilator public*/;

// Stage buffers

typedef struct packed {
    logic valid;
} fetch_dec_buff_t;

typedef struct packed {
    control_t control;
    rv_instr_t instr;
    l32 pc;
    l32 pc4;
    l32 imm;
    l32 [CORE_RF_NUM_READ - 1: 0] reg_data;
    l32 csr;
} dec_exec_buff_t;

// Bus definitions

typedef enum logic [2:0] {
    CBR_NOP,
    CBR_L,
    CBR_SB,
    CBR_SH,
    CBR_SW
} cbr_op_t /* verilator public */;

typedef struct packed {
    l32 addr;
    l32 data;
    cbr_op_t op;
} cbr_req_t /* verilator public */;

typedef struct packed {
    l32 data;
    logic done;
} cbr_res_t /* verilator public */;

// Translate core request to bus requests module as function

function automatic void mem_req_to_bus_req (
    input mem_request_t mem_req, 
    output cbr_req_t bus_req
);
    bus_req.addr = mem_req.addr;
    bus_req.data = mem_req.data;

    case (mem_req.op) 
        MEM_NOP: begin 
            bus_req.op = CBR_NOP;
        end
        MEM_SB: begin 
            bus_req.op = CBR_SB;
        end
        MEM_SH: begin 
            bus_req.op = CBR_SH;
        end
        MEM_SW: begin 
            bus_req.op = CBR_SW;
        end
        default: begin 
            bus_req.op = CBR_L;
        end
    endcase
endfunction

endpackage
