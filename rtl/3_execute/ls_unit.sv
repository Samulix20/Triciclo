module ls_unit
import triciclo_pkg::*;
(
    input logic clk, resetn,

    // Memory interface
    output mem_request_t data_req,
    input logic data_req_ack,
    input l32 data_resp_data,
    input logic data_resp_err,
    input logic data_resp_valid,

    // Control
    input logic start,
    input mem_request_t input_data_req,
    output logic ending,
    output l32 out_data,

    // This Functional Unit can trap
    output l32 trap_cause, trap_value, 
    output logic trap
);

typedef enum logic [1:0] {IDLE, WAIT_REQ_RDY, WAIT_DATA_VALID} state_t;
state_t state, next_state;

always_ff @(posedge clk) begin
    if (!resetn) state <= IDLE;
    else state <= next_state;
end

logic store_mem_req;
mem_request_t internal_req;

always_ff @(posedge clk) begin 
    if (!resetn) reserved_addr_valid <= 0;
    else if (store_mem_req) internal_req <= input_data_req;
end

l32 reserved_addr;
logic clear_reserved_addr, set_reserved_addr, reserved_addr_valid, sc_error, sc_ok;

always_ff @(posedge clk) begin
    if (!resetn || clear_reserved_addr) begin 
        reserved_addr_valid <= 0;
    end
    else if (set_reserved_addr) begin 
        reserved_addr_valid <= 1;
        reserved_addr <= internal_req.addr;
    end
end

l32 fixed_load;
load_fix load_fix (
    .op(internal_req.op), 
    .addr(internal_req.addr),
    .raw_load(data_resp_data),
    .fixed_load(fixed_load)
);

// Trap Control
logic ma;
always_comb begin
    trap = 0;
    trap_cause = 0;
    trap_value = internal_req.addr;
    ma = check_ma(internal_req.op, internal_req.addr[1:0]);

    if (state == WAIT_REQ_RDY) begin 
        if (is_store(internal_req.op)) begin 
            if (ma) begin 
                trap = 1;
                trap_cause = CAUSE_MISALIGNED_STORE;
            end
        end
        else if (internal_req.op != MEM_NOP) begin 
            if (ma) begin 
                trap = 1;
                trap_cause = CAUSE_MISALIGNED_LOAD;
            end
        end
    end
    else if (state == WAIT_DATA_VALID && data_resp_valid) begin 
        if (is_store(internal_req.op) && data_resp_err) begin
            trap = 1;
            trap_cause = CAUSE_STORE_ACCESS_FAULT;
        end
        else if (internal_req.op != MEM_NOP && data_resp_err) begin 
            trap = 1;
            trap_cause = CAUSE_LOAD_ACCESS_FAULT;
        end
    end
end

// Control op and sc
always_comb begin 
    data_req = internal_req;
    data_req.op = MEM_NOP;
    sc_error = 0;
    sc_ok = 0;

    if (state == WAIT_REQ_RDY && !trap) begin 
        if (internal_req.op == AMO_SC) begin 
            if (!reserved_addr_valid) sc_error = 1;
            else if (internal_req.addr != reserved_addr) sc_error = 1;
        end

        if (!sc_error) data_req.op = internal_req.op;
    end

    else if (state == WAIT_DATA_VALID) begin 
        if (internal_req.op == AMO_SC) sc_ok = 1; 
    end
end

always_comb begin
    next_state = state;
    ending = 0;
    store_mem_req = 0;
    set_reserved_addr = 0;
    clear_reserved_addr = 0;
    out_data = fixed_load;

    case (state)
        IDLE: begin 
            if (start) begin 
                next_state = WAIT_REQ_RDY;
                store_mem_req = 1;
            end 
        end
        WAIT_REQ_RDY: begin 
            if (trap) begin 
                next_state = IDLE;
                ending = 1;
            end
            else if (sc_error) begin 
                next_state = IDLE;
                ending = 1;
                out_data = 1;
            end
            else if (data_req_ack) begin
                next_state = WAIT_DATA_VALID;
            end
        end
        WAIT_DATA_VALID: begin 
            if (data_resp_valid) begin 
                next_state = IDLE;
                ending = 1;

                if (sc_ok) out_data = 0;
                if (internal_req.op == AMO_LR) set_reserved_addr = 1;
                if (is_store(internal_req.op) && reserved_addr == internal_req.addr) clear_reserved_addr = 1;
            end
        end
        default: begin end
    endcase

end

endmodule
