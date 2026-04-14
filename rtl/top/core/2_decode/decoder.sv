/* verilator lint_off UNUSEDSIGNAL */

/* 
 RISCV Instruction decoder
 - RV32I
 - Zicsr extension
*/

/*
 Custom extensions
 - GNRG
*/

module decoder
import triciclo_pkg::*;
(
    input rv_instr_t instr,
    output control_t control
);

logic is_srai;

always_comb begin
    // Logic for detecting SRAI instruction
    is_srai = 0;
    // Default signals NOP Setup add x0, x0, 0;
    control = create_nop_ctrl();
    control.bubble = 0;

    unique case(instr.opcode)
        // Load upper imm
        // RD = U_IMM
        OPCODE_LUI: begin
            control.imm = IMM_U;
            control.wb_result_src = WB_IMM;
            control.rf_write = 1;
        end

        // Load upper imm+pc
        // ALU: PC + U_IMM
        // RD = ALU
        OPCODE_AUIPC: begin
            control.imm = IMM_U;
            control.int_alu_input = ALU_IN_PC_IMM;
            control.rf_write = 1;
        end

        // Jump and link
        // ALU: PC + J_IMM
        // PC = ALU
        // RD = PC + (4 or 2)
        OPCODE_JAL: begin
            control.imm = IMM_J;
            control.branch_op = OP_J;
            control.int_alu_input = ALU_IN_PC_IMM;
            control.wb_result_src = WB_PC4;
            control.rf_write = 1;
        end

        // Jump and link using register
        // ALU: R1 + J_IMM
        // PC = ALU
        // RD = PC + (4 or 2)
        OPCODE_JALR: begin
            control.imm = IMM_I;
            control.branch_op = OP_J;
            control.int_alu_input = ALU_IN_R1_IMM;
            control.wb_result_src = WB_PC4;
            control.rf_write = 1;
        end

        // Branch instruction
        // ALU: PC + B_IMM
        // PC = ALU
        // B_UNIT: R1, R2
        OPCODE_BRANCH: begin
            control.imm = IMM_B;
            control.branch_op = branch_op_t'({1'b0, instr.funct3});
            control.int_alu_input = ALU_IN_PC_IMM;
        end

        // Integer Immediate arithmetic
        // ALU: R1, I_IMM
        // RD = ALU
        OPCODE_INTEGER_IMM: begin
            // SRAI instr is the only that sets alu_op to 1xxx
            if (instr.funct3 == 3'b101 && instr.funct7[5]) is_srai = 1;
            else is_srai = 0;
            control.imm = IMM_I;
            control.int_alu_op = int_alu_op_t'({is_srai, instr.funct3});
            control.int_alu_input = ALU_IN_R1_IMM;
            control.rf_write = 1;
        end

        // Integer register op register arithmetic
        // ALU: R1, R2
        // MUL: R1, R2
        // RD = ALU or MUL
        OPCODE_INTEGER_REG: begin
            control.rf_write = 1;

            case (instr.funct7)
                7'b0000001: begin // Mul extension
                    control.wb_result_src = WB_MUL;
                end
                default: begin // Base integer instructions
                    control.int_alu_op = int_alu_op_t'({instr.funct7[5], instr.funct3});
                    control.int_alu_input = ALU_IN_R1_R2;
                end
            endcase
        end

        // Store
        // ALU: R1 + S_IMM
        // MEM @ ALU <- R2
        OPCODE_STORE: begin
            control.imm = IMM_S;
            control.int_alu_input = ALU_IN_R1_IMM;
            control.mem_op = mem_op_t'({1'b1, instr.funct3});
            control.wb_result_src = WB_STORE;
        end

        // Load
        // ALU: R1 + I_IMM
        // RD = MEM @ ALU
        OPCODE_LOAD: begin
            control.imm = IMM_I;
            control.int_alu_input = ALU_IN_R1_IMM;
            control.mem_op = mem_op_t'({1'b0, instr.funct3});
            control.wb_result_src = WB_LOAD;
            control.rf_write = 1;
        end

        OPCODE_SYSTEM: begin
            // PRIV subopcode
            if (instr.funct3 == 'b000) begin 
                // MRET
                if (instr[31:20] == 'b001100000010) begin
                    control.trap_type = TRAP_MRET;
                end
                // ECALL
                else if (instr[31:20] == 'b000000000000) begin 
                    control.trap_type = TRAP_ECALL;
                end
                // EBREAK
                else if (instr[31:20] == 'b000000000001) begin 
                    control.trap_type = TRAP_EBREAK;
                end
            end
            // Zicsr
            // CSR = Zicsr csr result
            // RD = Zicsr reg result
            else begin
                // RD = CSR
                control.rf_write = 1;
                control.csr_write = 1;
                control.wb_result_src = WB_CSR;
            end
        end

        OPCODE_BARRIER: begin 
            // Behaves as NOP but does not cause a TRAP 
        end

        OPCODE_AMO: begin 
            if (instr.funct3 == 3'b010) begin
                // LR.W
                if (instr.funct7[6:2] == 5'b00010) begin 
                    // RS1 used as address directly
                    control.int_alu_input = ALU_IN_R1_IMM;
                    control.imm = IMM_0;
                    control.mem_op = MEM_LW;
                    control.amo_op = AMO_LR;
                    control.wb_result_src = WB_LOAD;
                    control.rf_write = 1;
                end
                // SC.W
                else if (instr.funct7[6:2] == 5'b00011) begin 
                    // RS1 used as address directly
                    control.int_alu_input = ALU_IN_R1_IMM;
                    control.imm = IMM_0;
                    control.mem_op = MEM_SW;
                    control.amo_op = AMO_SC;
                    control.wb_result_src = WB_STORE;
                    control.rf_write = 1;
                end
                else begin 
                    control.trap_type = TRAP_ILLEGAL;
                end
            end
            else begin 
                control.trap_type = TRAP_ILLEGAL;
            end
        end

        default: begin
            // Invalid instruction detection
            control.trap_type = TRAP_ILLEGAL;
        end
    endcase

    if (instr.rd == 0) control.rf_write = 0;
end


endmodule
