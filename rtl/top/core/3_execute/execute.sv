/* verilator lint_off UNUSEDSIGNAL */

module execute 
import triciclo_pkg::*;
(
    input logic clk, resetn, enable,

    // Pipeline D-E
    input dec_exec_buff_t dec_data,
    output logic exec_ready,

    // Data Mem I/O
    output mem_request_t data_req,
    input logic data_req_ack,
    input l32 mem_data,
    input logic data_req_done,

    // Register File
    output rf_write_request_t rf_req_reg,
    // Csr
    output csr_write_request_t csr_req_reg,
    output logic instr_ret,

    // Flush
    output flush_bus_t flush_bus,

    // Traps
    input logic mtip, msip, meip,
    input trap_config_t trap_conf,
    output trap_type_t trap
);

typedef enum logic [2:0] {
    IDLE,
    MEM_ADDR,
    MEM_WAIT,
    MUL_BEGIN,
    MUL_END
} state_t;
state_t state, next_state;

// Bypass last write
l32 [CORE_RF_NUM_READ - 1:0] reg_data;
rv_reg_id_t [CORE_RF_NUM_READ - 1:0] rf_read_ids;

always_comb begin 
    for (int i = 0; i < CORE_RF_NUM_READ; i += 1) reg_data[i] = dec_data.reg_data[i];
end

l32 alu_op1, alu_op2, int_alu_out;
always_comb begin 
    case (dec_data.control.int_alu_input)
        ALU_IN_PC_IMM: begin 
            alu_op1 = dec_data.pc;
            alu_op2 = dec_data.imm;
        end
        ALU_IN_R1_IMM: begin 
            alu_op1 = reg_data[0];
            alu_op2 = dec_data.imm;
        end
        default: begin 
            alu_op1 = reg_data[0];
            alu_op2 = reg_data[1];
        end
    endcase
end
int_alu int_alu (
    .op1(alu_op1), .op2(alu_op2), .result(int_alu_out),
    .opsel(dec_data.control.int_alu_op)
);

l32 zicsr_operand, zicsr_reg_result, zicsr_csr_result;
zicsr_op_t zicsr_op;
always_comb begin
    zicsr_op = zicsr_op_t'(dec_data.instr.funct3[1:0]);
    // Register
    if (dec_data.instr.funct3[2] == 0) zicsr_operand = reg_data[0];
    // Special Immediate
    else begin
        zicsr_operand[4:0] = dec_data.instr.rs1;
        zicsr_operand[31:5] = 0;
    end
end
zicsr zicsr(
    .csr(dec_data.csr), .operand(zicsr_operand),
    .opsel(zicsr_op),
    .reg_result(zicsr_reg_result), .csr_result(zicsr_csr_result)
);

l32 mul_result;
logic set_mul_ops, do_mul;
mul_op_t mul_op; assign mul_op = get_mul_op(dec_data.instr);
int_mul int_mul (
    .clk(clk),
    .op1(reg_data[0]), .op2(reg_data[1]),
    .opsel(mul_op), .result(mul_result),
    .set_ops(set_mul_ops), .do_mul(do_mul)
);

logic do_branch;
branch branch (
    .op1(reg_data[0]), .op2(reg_data[1]),
    .branch_op(dec_data.control.branch_op),
    .do_branch(do_branch)
);

l32 request_addr, request_data, fixed_load;
logic store_mem_req;
load_fix load_fix (
    .op(dec_data.control.mem_op), 
    .addr(request_addr), .raw_load(mem_data),
    .fixed_load(fixed_load)
);

csr_write_request_t current_csr_req;
rf_write_request_t current_rf_req;
always_comb begin
    // CSRs
    current_csr_req.id = dec_data.instr[31:20];
    current_csr_req.data = zicsr_csr_result;

    // Register file, output MUX
    current_rf_req.id = dec_data.instr.rd;
    case (dec_data.control.wb_result_src)
        WB_IMM: current_rf_req.data = dec_data.imm;
        WB_PC4: current_rf_req.data = dec_data.pc4;
        WB_LOAD: current_rf_req.data = fixed_load;
        WB_MUL: current_rf_req.data = mul_result;
        WB_CSR: current_rf_req.data = zicsr_reg_result;
        default: current_rf_req.data = int_alu_out;
    endcase
end

// Memory request
always_comb begin 
    // These are just comb paths
    data_req.addr = request_addr;
    data_req.data = request_data;

    // Send the data request
    if (state == MEM_ADDR) data_req.op = dec_data.control.mem_op;
    else data_req.op = MEM_NOP;
end

// Check for traps
always_comb begin
    flush_bus.from = dec_data.pc;
    flush_bus.cause = 0;
    flush_bus.value = 0;
    trap = NO_TRAP;

    // IRQ
    if (meip && trap_conf.mstatus.mie && trap_conf.mie.meie) begin
        trap = TRAP_IRQ;
        flush_bus.cause = CAUSE_EXT_IRQ;
    end
    else if (mtip && trap_conf.mstatus.mie && trap_conf.mie.mtie) begin 
        trap = TRAP_IRQ;
        flush_bus.cause = CAUSE_TIMER_IRQ;
    end
    else if (msip && trap_conf.mstatus.mie && trap_conf.mie.msie) begin 
        trap = TRAP_IRQ;
        flush_bus.cause = CAUSE_SOFT_IRQ;
    end
    else if (dec_data.control.trap_type == TRAP_ECALL) begin
        trap = TRAP_ECALL;
        flush_bus.cause = CAUSE_MACHINE_ECALL;
    end
    else if (dec_data.control.trap_type == TRAP_ILLEGAL) begin
        trap = TRAP_IRQ;
        flush_bus.cause = CAUSE_ILLEGAL_INSTRUCTION;
    end
    else if (dec_data.control.trap_type == TRAP_MRET) begin
        trap = TRAP_MRET;
    end

    if (trap == TRAP_MRET) flush_bus.to = trap_conf.mepc;
    else if (trap != NO_TRAP) flush_bus.to = trap_conf.mtvec;
    else flush_bus.to = int_alu_out;
end

always_comb begin
    next_state = state;

    // Important signals controlled by state machine
    flush_bus.op = NO_FLUSH;
    current_rf_req.write_enable = 0;
    current_csr_req.write_enable = 0;
    exec_ready = 0;
    set_mul_ops = 0; 
    do_mul = 0;
    store_mem_req = 0;

    case (state)
        IDLE: begin
            if (enable) begin
                if (trap != NO_TRAP) begin 
                    flush_bus.op = FLUSH_TRAP;
                end
                // Memory instructions
                else if (dec_data.control.mem_op != MEM_NOP) begin 
                    store_mem_req = 1;
                    next_state = MEM_ADDR;
                end
                // Multiplication instructions, multicycle
                else if (dec_data.control.wb_result_src == WB_MUL) begin 
                    set_mul_ops = 1;
                    next_state = MUL_BEGIN;
                end
                // Branch instruction
                else if (do_branch) begin 
                    exec_ready = 1;
                    flush_bus.op = FLUSH_BRANCH;
                    current_rf_req.write_enable = dec_data.control.rf_write;
                end
                // Other 1 cycle instructions
                else begin 
                    exec_ready = 1;
                    current_rf_req.write_enable = dec_data.control.rf_write;
                    current_csr_req.write_enable = dec_data.control.csr_write;
                end
            end
        end

        MEM_ADDR: begin
            // Memory accepts operation
            if (data_req_ack) begin 
                // Dont need to wait for stores
                if(is_mem_store(dec_data.control.mem_op)) begin
                    exec_ready = 1;
                    next_state = IDLE;
                end
                // Wait for the load data
                else begin 
                    next_state = MEM_WAIT;
                end
            end
        end
        MEM_WAIT: begin 
            if (data_req_done) begin 
                current_rf_req.write_enable = dec_data.control.rf_write;
                exec_ready = 1;
                next_state = IDLE;
            end
        end

        MUL_BEGIN: begin 
            do_mul = 1;
            next_state = MUL_END;
        end
        MUL_END: begin 
            current_rf_req.write_enable = dec_data.control.rf_write;
            exec_ready = 1;
            next_state = IDLE;
        end

        default: begin end
    endcase
end

// Count new instruction
assign instr_ret = (exec_ready & dec_data.control.bubble);

always_comb begin 
    rf_req_reg = current_rf_req;
    csr_req_reg = current_csr_req;
end

always_ff @(posedge clk) begin
    if (!resetn) state <= IDLE;
    else state <= next_state;
end

// Data request Bus
always_ff @(posedge clk) begin
    if (store_mem_req) begin
        request_addr <= int_alu_out;
        request_data <= reg_data[1];
    end
end

endmodule
