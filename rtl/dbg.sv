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
    output logic halt_req, step_req, haltonr_req, resume_req, dbg_reset,
    output logic fetch_enable
 


    // output logic        core_enable
);
 

typedef enum logic [3:0] {
    DBG_RUNNING         = 4'd0,
    DBG_HALTING         = 4'd1,
    DBG_HALTED          = 4'd2,
    DBG_STEP_REQ        = 4'd3,
    DBG_STEPPING        = 4'd4,
    DBG_STEP_HALTING    = 4'd5,
    DBG_RRESUMING       = 4'd6,
    DBG_RRESETHALTING   = 4'd7,
    DBG_RRESETTING      = 4'd8
} dbg_state_t;
 
dbg_state_t state, state_next;
 




assign fetch_enable  = (!(state == DBG_HALTED || state == DBG_RRESUMING));
assign dbg_reset  = (state == DBG_RRESETHALTING || state == DBG_RRESETTING || resetn);

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
                state_next = DBG_RRESETTING;
            else if (dbg_core_control.reset_request && dbg_core_control.halt_request)
                state_next = DBG_RRESETHALTING;
        end
 
        DBG_HALTING: begin
            if (flush_bus.op == FLUSH_DEBUG_ENTRY)
                state_next = DBG_HALTED;
        end
 
        DBG_HALTED: begin
            if (!dbg_core_control.resumeACK && !trap_conf.dcsr.step)
                state_next = DBG_RRESUMING;
            else if (!dbg_core_control.resumeACK && trap_conf.dcsr.step)
                state_next = DBG_STEP_REQ;
            else if (dbg_core_control.reset_request && !dbg_core_control.halt_request)
                state_next = DBG_RRESETTING;
            else if (dbg_core_control.reset_request && dbg_core_control.halt_request)
                state_next = DBG_RRESETHALTING;
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
 
        DBG_RRESUMING: begin
            if (flush_bus.op == FLUSH_DEBUG_RETURN)
                state_next = DBG_RUNNING;
        end

        DBG_RRESETTING: begin
            state_next = DBG_RUNNING;
        end

        DBG_RRESETHALTING: begin
            state_next = DBG_HALTING;
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
 
        DBG_RRESUMING: begin
            // Core status
            dbg_core_status.running <= 0;
            dbg_core_status.halted <= 1;
            dbg_core_status.resumeACK <= 0;

            // Traps
            resume_req <= 1;
        end

        DBG_RRESETTING: begin
            // Core status
            dbg_core_status.running <= 0;
            dbg_core_status.halted <= 0;
            dbg_core_status.havereset <= 1;
            dbg_core_status.resumeACK <= 1;
        end

        DBG_RRESETHALTING: begin
            // Core status
            dbg_core_status.running <= 0;
            dbg_core_status.halted <= 0;
            dbg_core_status.havereset <= 1;
            dbg_core_status.resumeACK <= 1;
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
 
