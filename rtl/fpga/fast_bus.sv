module fast_bus 
import triciclo_pkg::*;
(
    // Master input
    input cbr_req_t master_req,
    output logic master_ack,
    output cbr_res_t master_res,

    // Slaves outputs
    output cbr_req_t slaves_req [2],
    input logic slaves_rdy [2],
    input cbr_res_t slaves_res [2]
);

always_comb begin 
    slaves_req[0] = master_req;
    slaves_req[1] = master_req;

    // High mems addrs are for slow bus (2 GB)
    if (master_req.addr[31] == 1) begin 
        // Send NOP to the other
        slaves_req[0].op = CBR_NOP;
        master_ack = slaves_rdy[1];
        master_res = slaves_res[1];
    end
    // Low mem reqs for BRAM (2 GB)
    else begin 
        // Send NOP to the other
        slaves_req[1].op = CBR_NOP;
        master_ack = slaves_rdy[0];
        master_res = slaves_res[0];
    end
end


endmodule

