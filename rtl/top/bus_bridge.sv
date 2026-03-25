module bus_bridge
import triciclo_pkg::*;
(
    input logic clk, resetn,

    input cbr_req_t slave_port_req,
    output logic slave_port_rdy,
    output cbr_res_t slave_port_res,

    output cbr_req_t master_port_req,
    input logic master_port_rdy,
    input cbr_res_t master_port_res
);

typedef enum {IDLE, WAIT_ACK, WAIT_DONE} state_t;
state_t state, next_state;

logic accept_req, clear_req;
always_ff @(posedge clk) begin
    if (!resetn) master_port_req.op <= CBR_NOP;
    else if (accept_req) master_port_req <= slave_port_req;
    else if (clear_req) master_port_req.op <= CBR_NOP;
end

logic set_response;
always_ff @(posedge clk) begin
    // Done just stays up 1 cycle
    if (!resetn) slave_port_res.done <= 0;
    else if (set_response) slave_port_res <= master_port_res;
    else slave_port_res.done <= 0;
end

always_ff @(posedge clk) begin
    if (!resetn) state <= IDLE;
    else state <= next_state;
end

assign slave_port_rdy = (state == IDLE);

always_comb begin
    // Default values
    next_state = state;
    accept_req = 0;
    clear_req = 0;
    set_response = 0;

    case (state)
        IDLE: begin
            if (slave_port_req.op != CBR_NOP) begin 
                accept_req = 1;
                next_state = WAIT_ACK;
            end
        end
        WAIT_ACK: begin 
            if (master_port_rdy) begin 
                clear_req = 1;
                next_state = WAIT_DONE;
            end
        end
        WAIT_DONE: begin 
            if (master_port_res.done) begin 
                set_response = 1;
                next_state = IDLE;
            end
        end
        default: begin end
    endcase
end


endmodule
