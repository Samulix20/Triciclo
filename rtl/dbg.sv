/* verilator lint_off UNUSEDSIGNAL */
module dbg
    import triciclo_pkg::*;
(
    input  logic clk,
    input  logic resetn,


    input  dbg_core_control_t dbg_core_control,
    output dbg_core_status_t dbg_core_status,
 
    input flush_bus_t flush_bus,
    input logic instr_ret,
    input trap_config_t trap_conf,
    input l32 read_data,
    output logic halt_req, step_req, haltonr_req, resume_req, dbg_reset,
    output logic fetch_enable, dbg_reg_enable, exec_pb
 


    // output logic        core_enable
);
 

typedef enum logic [3:0] {
    DBG_RUNNING         = 4'd0,
    DBG_HALTING         = 4'd1,
    DBG_HALTED          = 4'd2,
    DBG_STEP_REQ        = 4'd3,
    DBG_STEPPING        = 4'd4,
    DBG_STEP_HALTING    = 4'd5,
    DBG_RESUMING        = 4'd6,
    DBG_RESETHALTING    = 4'd7,
    DBG_RESETTING       = 4'd8,
    DBG_ACCESS_REGISTER = 4'd9,
    DBG_RESUME_PB       = 4'd10,
    DBG_EXEC_PB         = 4'd11
} dbg_state_t;
 
dbg_state_t state, state_next;
 




assign fetch_enable  = (!(state == DBG_HALTED || state == DBG_RESUMING || state == DBG_STEP_REQ || state == DBG_RESUME_PB));
assign dbg_reset  = (state == DBG_RESETHALTING || state == DBG_RESETTING || resetn);
assign dbg_reg_enable = (state == DBG_ACCESS_REGISTER);
assign exec_pb = (state == DBG_RESUME_PB || state == DBG_EXEC_PB);

always_ff @(posedge clk) begin
    if (!resetn)
        state <= DBG_RUNNING;
    else
        state <= state_next;
end

always_comb begin
    state_next = state;
 
    case (state)
 
        DBG_RUNNING: begin
            if (!dbg_core_control.reset_request && dbg_core_control.halt_request)
                state_next = DBG_HALTING;
            else if (dbg_core_control.reset_request && !dbg_core_control.halt_request)
                state_next = DBG_RESETTING;
            else if (dbg_core_control.reset_request && dbg_core_control.halt_request)
                state_next = DBG_RESETHALTING;
        end
 
        DBG_HALTING: begin
            if (flush_bus.op == FLUSH_DEBUG_ENTRY)
                state_next = DBG_HALTED;
        end
 
        DBG_HALTED: begin
            if (!dbg_core_control.resumeACK && !trap_conf.dcsr.step)
                state_next = DBG_RESUMING;
            else if (!dbg_core_control.resumeACK && trap_conf.dcsr.step)
                state_next = DBG_STEP_REQ;
            else if (dbg_core_control.reset_request && !dbg_core_control.halt_request)
                state_next = DBG_RESETTING;
            else if (dbg_core_control.reset_request && dbg_core_control.halt_request)
                state_next = DBG_RESETHALTING;
            else if (dbg_core_control.abs_access_reg)
                state_next = DBG_ACCESS_REGISTER;
            else if (dbg_core_control.pb_exec)
                state_next = DBG_RESUME_PB;
        end
 
        DBG_STEP_REQ: begin
            if (flush_bus.op == FLUSH_DEBUG_RETURN)
                state_next = DBG_STEPPING;
        end
 
        DBG_STEPPING: begin
            if (instr_ret)
                state_next = DBG_STEP_HALTING;
        end
 
        DBG_STEP_HALTING: begin
            if (flush_bus.op == FLUSH_DEBUG_ENTRY)
                state_next = DBG_HALTED;
        end
 
        DBG_RESUMING: begin
            if (flush_bus.op == FLUSH_DEBUG_RETURN)
                state_next = DBG_RUNNING;
        end

        DBG_RESETTING: begin
            state_next = DBG_RUNNING;
        end

        DBG_RESETHALTING: begin
            state_next = DBG_HALTING;
        end


        DBG_ACCESS_REGISTER: begin
            state_next = DBG_HALTED;
        end


        DBG_RESUME_PB: begin
            if (flush_bus.op == FLUSH_DEBUG_RETURN)
                state_next = DBG_RUNNING;
        end


        DBG_EXEC_PB: begin
            if (flush_bus.op == FLUSH_DEBUG_ENTRY)
                state_next = DBG_HALTED;
        end

        default: state_next = DBG_RUNNING;
 
    endcase
end

 
always_ff @(posedge clk) begin
    dbg_core_status.abs_end <= 0;
    dbg_core_status.running <= 0;
    dbg_core_status.halted <= 0;
    dbg_core_status.havereset <= 0;
    dbg_core_status.resumeACK <= 1;
    dbg_core_status.reg_read <= read_data;
    halt_req <= 0;
    step_req <= 0;
    haltonr_req <= 0;
    resume_req <= 0;
    

    if (!resetn) begin
        


    end else begin
        case (state)
        DBG_RUNNING: begin
            // Core status
            dbg_core_status.running <= 1;
            dbg_core_status.halted <= 0;
            dbg_core_status.resumeACK <= 1;

            // Traps

        end
 
        DBG_HALTING: begin
            // Core status
            dbg_core_status.running <= 1;
            dbg_core_status.halted <= 0;
            dbg_core_status.resumeACK <= 1;

            // Traps
            halt_req <= 1;
        end
 
        DBG_HALTED: begin
            // Core status
            dbg_core_status.running <= 0;
            dbg_core_status.halted <= 1;
            dbg_core_status.resumeACK <= 1;

            // Traps
        end
 
        DBG_STEP_REQ: begin
            // Core status
            dbg_core_status.running <= 0;
            dbg_core_status.halted <= 1;
            dbg_core_status.resumeACK <= 1;

            // Traps
            resume_req <= 1;
        end
 
        DBG_STEPPING: begin
            // Core status
            dbg_core_status.running <= 1;
            dbg_core_status.halted <= 0;
            dbg_core_status.resumeACK <= 1;

            // Traps
        end
 
        DBG_STEP_HALTING: begin
            // Core status
            dbg_core_status.running <= 1;
            dbg_core_status.halted <= 0;
            dbg_core_status.resumeACK <= 1;

            // Traps
            step_req <= 1;
        end
 
        DBG_RESUMING: begin
            // Core status
            dbg_core_status.running <= 0;
            dbg_core_status.halted <= 1;
            dbg_core_status.resumeACK <= 0;

            // Traps
            resume_req <= 1;
        end

        DBG_RESETTING: begin
            // Core status
            dbg_core_status.running <= 1;
            dbg_core_status.halted <= 0;
            dbg_core_status.havereset <= 1;
            dbg_core_status.resumeACK <= 1;
        end

        DBG_RESETHALTING: begin
            // Core status
            dbg_core_status.running <= 0;
            dbg_core_status.halted <= 1;
            dbg_core_status.havereset <= 1;
            dbg_core_status.resumeACK <= 1;
        end


        DBG_ACCESS_REGISTER: begin
            dbg_core_status.running <= 0;
            dbg_core_status.halted <= 1;
            dbg_core_status.resumeACK <= 1;
        end


        DBG_RESUME_PB: begin
            // Core status
            dbg_core_status.running <= 0;
            dbg_core_status.halted <= 0;
            dbg_core_status.resumeACK <= 0;

            // Traps
            resume_req <= 1;

        end


        DBG_EXEC_PB: begin
            // Core status
            dbg_core_status.running <= 1;
            dbg_core_status.halted <= 0;
            dbg_core_status.resumeACK <= 1;

            // Traps
            halt_req <= 1;
        end
 
        default: begin
            // Core status
            dbg_core_status.running <= 1;
            dbg_core_status.halted <= 0;
            dbg_core_status.resumeACK <= 1;

            // Traps
        end
 
        endcase
    end
end
 
 
endmodule
 
