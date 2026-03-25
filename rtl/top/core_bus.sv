
module core_bus 
import triciclo_pkg::*;
# (
    parameter int NREGIONS = 3,
    parameter logic [31:0] ADDR_RANGES [2 * NREGIONS] = {
        // Region 1
        'h0000_0000, 
        'h0FFF_FFFF,
        // Region 2
        'h1000_0000,
        'h7FFF_FFFF,
        // Region 3
        'h8000_0000, 
        'hFFFF_FFFF
    },
    parameter int NSLAVES = 2,
    parameter int SLAVE_ID_BITS = $clog2(NSLAVES),
    parameter logic [SLAVE_ID_BITS - 1: 0] REGION_SLAVE_MAP [NREGIONS] = {
        0, // Map region 1 to slave 0
        1, // Map region 2 to slave 1
        0  // Map region 3 to slave 0
    },
    parameter int NMASTERS = 2,
    parameter int MASTER_ID_BITS = $clog2(NMASTERS)
)
(
    input logic clk,
    input logic resetn,

    input cbr_req_t i_ms_req [NMASTERS],
    output logic o_ms_rdy [NMASTERS],
    output cbr_res_t o_ms_res [NMASTERS],

    output cbr_req_t o_accepted_op,

    output cbr_req_t o_slv_req [NSLAVES],
    input cbr_res_t i_slv_res [NSLAVES],
    input logic i_slv_rdy [NSLAVES]
);

localparam __MASTER_ID_BITS = clamp0(MASTER_ID_BITS - 1);

typedef logic [SLAVE_ID_BITS - 1: 0] slv_id_t;
typedef logic [__MASTER_ID_BITS : 0] master_id_t; 

logic addr_in_range;
slv_id_t slv_id, slv_id_reg;
master_id_t master_id, master_id_reg;

logic [MASTER_ID_BITS : 0] master_rr;

cbr_req_t selected_ms_req;
logic selected_ms_ready;
logic selected_done;

always_comb begin 
    master_id = master_rr[__MASTER_ID_BITS : 0];
    selected_ms_req = i_ms_req[master_id];
end

// Region Address range -> to slave id decoder
always_comb begin 
    // Default no addr in range so no ready
    addr_in_range = 0;
    for (int i = 0; i < NMASTERS; i += 1) begin 
        o_ms_rdy[i] = 0;
    end
    
    // Slave id defaults to 0
    slv_id = 0;
    
    for (int i = 0; i < NREGIONS; i += 1) begin 
        // Request in addr bounds for region i
        if (selected_ms_req.addr >= ADDR_RANGES[2 * i] && selected_ms_req.addr <= ADDR_RANGES[2 * i + 1]) begin 
            slv_id = REGION_SLAVE_MAP[i];
            addr_in_range = 1;
        end
    end

    // If addres was in any range set the ready from the slave
    if (addr_in_range) o_ms_rdy[master_id] = i_slv_rdy[slv_id];
    selected_ms_ready = o_ms_rdy[master_id];
end

logic can_grant;
logic request_handshake;
logic pending_request_reg;

always_comb begin
    // No pending request or pending request finished
    can_grant = !pending_request_reg || (pending_request_reg && selected_done);

    // Fanout requests
    // Default no one gets an operation
    for (int i = 0; i < NSLAVES; i += 1) begin 
        o_slv_req[i] = selected_ms_req;
        o_slv_req[i].op = CBR_NOP;
    end

    // If bus can be granted send operation to slave using region map
    if (can_grant) begin 
        o_slv_req[slv_id].op = selected_ms_req.op;
    end

    // Bus can be granted, master wants to do an operation and slave is ready
    request_handshake = (o_slv_req[slv_id].op != CBR_NOP && selected_ms_ready);
    
    // Output accepted op for LR SC
    o_accepted_op = selected_ms_req;
    if (!request_handshake) o_accepted_op.op = CBR_NOP;

end

always_ff @(posedge clk) begin
    if (!resetn) begin 
        pending_request_reg <= 0;
    end
    // Request handshake
    else if (request_handshake) begin 
        slv_id_reg <= slv_id;
        master_id_reg <= master_id;
        pending_request_reg <= 1;
    end
    // Any request ended and no handshake
    else if (selected_done) begin 
        pending_request_reg <= 0;
    end
end

always_comb begin 
    selected_done = 0;
    // Default all signals to 0
    for (int i = 0; i < NMASTERS; i += 1) begin 
        o_ms_res[i] = '{default: 0};
    end
    // Response mux
    if (pending_request_reg) begin 
        o_ms_res[master_id_reg] = i_slv_res[slv_id_reg];
        selected_done = i_slv_res[slv_id_reg].done;
    end
end

// Master round robin
always_ff @(posedge clk) begin 
    if (!resetn) begin 
        master_rr <= 0;
    end
    else begin 
        if (int'(master_rr) + 1 == NMASTERS) master_rr <= 0;
        else master_rr <= master_rr + 1;
    end
end


endmodule;
