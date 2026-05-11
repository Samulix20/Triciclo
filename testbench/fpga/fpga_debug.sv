module fpga_debug
import triciclo_pkg::*;
#(
    parameter int unsigned DATA_ADDR = 'h10600000,
    parameter int unsigned CTRL_ADDR = 'h10600010,
    parameter int unsigned EXIT_ADDR = 'h10601000
) 
(
    input logic clk, resetn,

    input cbr_req_t bus_req,
    output logic bus_rdy,
    output cbr_res_t bus_res,

    input logic [31:0] ctrl_reg,

    output logic core_data_write,
    output logic [31:0] o_data,
    output logic core_exit
);

// Always ready
assign bus_rdy = 1;
assign core_data_write = (bus_req.addr == DATA_ADDR && bus_req.op == CBR_SW);
assign core_exit = (bus_req.addr == EXIT_ADDR && bus_req.op == CBR_SW);

always_ff @(posedge clk) begin
    if (!resetn) begin
        bus_res.data <= 0;
        bus_res.done <= 0;
        o_data <= 0;
    end
    else begin 
        // Data reg write access
        if (core_data_write) begin 
            o_data[7:0] <= bus_req.data[7:0];
            bus_res.done <= 1;
        end
        // Control reg read access
        else if (bus_req.addr == CTRL_ADDR && bus_req.op == CBR_L) begin 
            bus_res.data <= ctrl_reg;
            bus_res.done <= 1;
        end
        else if (core_exit) begin 
            o_data[15:8] <= bus_req.data[7:0];
            bus_res.done <= 1;
        end
        // No request clear the register
        else begin 
            bus_res.done <= 0;
        end
    end
end


endmodule
