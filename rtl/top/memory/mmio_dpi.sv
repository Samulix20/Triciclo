module mmio_dpi 
import triciclo_pkg::*;
(
    input logic clk, resetn,

    input cbr_req_t i_req,
    output logic o_rdy,
    output cbr_res_t o_res
);

// Always ready
always_comb begin 
    o_rdy = 1;
end

import "DPI-C" function int dpi_mmio(int addr, int data, int op);

always_ff @(posedge clk) begin 

    if (i_req.op != CBR_NOP) begin
        o_res.data <= dpi_mmio(i_req.addr, i_req.data, int'(i_req.op));
    end

    // Handshake
    if (!resetn) begin 
        o_res.done <= 0;
    end
    else if (i_req.op != CBR_NOP && o_rdy) begin 
        o_res.done <= 1;
    end
    else begin 
        o_res.done <= 0;
    end

end


endmodule;
