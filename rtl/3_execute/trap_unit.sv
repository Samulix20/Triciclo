/* verilator lint_off UNUSEDSIGNAL */

module trap_unit
import triciclo_pkg::*;
(
    input logic mtip, msip, meip,
    input logic halt_req, step_req, haltonr_req, resume_req, pb_resume_req,
    input dec_exec_buff_t dec_data,
    input trap_config_t trap_conf,
    input logic pma_fault_jump, ma_jump,
    input l32 alu_result,
    output logic trap,
    output flush_bus_t flush_bus
);

always_comb begin 
    flush_bus.op = FLUSH_TRAP;
    flush_bus.from = dec_data.pc;
    flush_bus.to = trap_conf.mtvec;
    flush_bus.cause = 0;
    flush_bus.value = 0;
    trap = 0;

    // Debug IRQs 
    if (halt_req) begin
        trap = 1;
        flush_bus.op    = FLUSH_DEBUG_ENTRY;
        flush_bus.cause = 32'(DCSR_CAUSE_HALTREQ);
    end
    else if (dec_data.control.trap_type == TRAP_EBREAK && (trap_conf.dcsr.ebreakm || trap_conf.current_mode == MODE_DEBUG)) begin
        trap = 1;
        flush_bus.op    = FLUSH_DEBUG_ENTRY;
        flush_bus.cause = 32'(DCSR_CAUSE_EBREAK);
    end
    else if (step_req) begin
        trap = 1;
        flush_bus.op    = FLUSH_DEBUG_ENTRY;
        flush_bus.cause = 32'(DCSR_CAUSE_STEP);
    end
    else if (haltonr_req) begin
        trap = 1;
        flush_bus.op    = FLUSH_DEBUG_ENTRY;
        flush_bus.cause = 32'(DCSR_CAUSE_RESETHALTREQ);
    end
    else if (resume_req) begin
        trap = 1;
        flush_bus.op    = FLUSH_DEBUG_RETURN;
        flush_bus.from = trap_conf.dpc;
        flush_bus.to = trap_conf.dpc;
    end
    else if (pb_resume_req) begin
        trap = 1;
        flush_bus.op    = FLUSH_DEBUG_PB_RETURN;
        flush_bus.from = trap_conf.dpc;
        flush_bus.to = trap_conf.dpc;
    end
    // IRQs
    else if (meip && trap_conf.mstatus.mie && trap_conf.mie.meie) begin
        trap = 1;
        flush_bus.cause = CAUSE_EXT_IRQ;
    end
    else if (mtip && trap_conf.mstatus.mie && trap_conf.mie.mtie) begin 
        trap = 1;
        flush_bus.cause = CAUSE_TIMER_IRQ;
    end
    else if (msip && trap_conf.mstatus.mie && trap_conf.mie.msie) begin 
        trap = 1;
        flush_bus.cause = CAUSE_SOFT_IRQ;
    end
    else if (ma_jump) begin 
        trap = 1;
        flush_bus.cause = CAUSE_MISALIGNED_FETCH;
        flush_bus.value = alu_result;
    end
    else if (pma_fault_jump) begin 
        trap = 1;
        flush_bus.from = alu_result;
        flush_bus.cause = CAUSE_INSTRUCTION_ACCESS_FAULT;
    end
    else if (dec_data.control.trap_type == TRAP_ECALL) begin
        trap = 1;
        if (trap_conf.current_mode == MODE_MACHINE) flush_bus.cause = CAUSE_MACHINE_ECALL;
        else flush_bus.cause = CAUSE_USER_ECALL;
    end
    else if (dec_data.control.trap_type == TRAP_ILLEGAL) begin
        trap = 1;
        flush_bus.cause = CAUSE_ILLEGAL_INSTRUCTION;
        flush_bus.value = dec_data.instr;
    end
    else if (dec_data.control.trap_type == TRAP_MRET) begin
        trap = 1;
        flush_bus.op = FLUSH_MRET;
        flush_bus.from = trap_conf.mepc;
        flush_bus.to = trap_conf.mepc;
    end
end

endmodule
