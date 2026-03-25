
/*

Only supports word write

*/

`include "axi4_lite.svh"

module axi4_lite_master
import triciclo_pkg::*;
#(
    // Derived parameters
    parameter int WDATA = 32,
    parameter int WADDR = 32,
    parameter int WSTROBES = WDATA / 8
)
(
    input logic clk, resetn,

    // Core Interface
    input cbr_req_t i_req,
    output logic o_rdy,
    output cbr_res_t o_res,

    // AXI4-LITE-MS interface
    /* verilator lint_off UNUSEDSIGNAL */
    `AXI4_LITE_MASTER_IO(intf)
    /* verilator lint_on UNUSEDSIGNAL */
);


// Write RDY/VLD master channel
logic start_write_valid;

always_ff @(posedge clk) begin
    if (!resetn) begin 
        o_intf_axi_awvalid <= 0;
        o_intf_axi_wdvalid <= 0;
        o_intf_axi_bready <= 0;
    end
    else if (start_write_valid) begin
            o_intf_axi_awvalid <= 1;
            o_intf_axi_awaddr <= i_req.addr;
            o_intf_axi_wdvalid <= 1;
            o_intf_axi_wddata <= i_req.data;
            o_intf_axi_bready <= 1;
        end
    else begin
        if (o_intf_axi_awvalid && i_intf_axi_awready) begin 
            o_intf_axi_awvalid <= 0;
        end
        if (o_intf_axi_wdvalid && i_intf_axi_wdready) begin
            o_intf_axi_wdvalid <= 0;
        end
        if (o_intf_axi_bready && i_intf_axi_bvalid) begin 
            o_intf_axi_bready <= 0;
        end
    end
end

// Read RDY/VLD master channel
logic start_read_valid;

always_ff @(posedge clk) begin
    if (!resetn) begin 
        o_intf_axi_arvalid <= 0;
        o_intf_axi_rready <= 0;
    end
    else if (start_read_valid) begin
        o_intf_axi_rready <= 1;
        o_intf_axi_arvalid <= 1;
        o_intf_axi_araddr <= i_req.addr;
    end
    else begin 
        if (o_intf_axi_arvalid && i_intf_axi_arready) begin 
            o_intf_axi_arvalid <= 0;
        end
        if (o_intf_axi_rready && i_intf_axi_rvalid) begin
            o_intf_axi_rready <= 0;
            o_res.data <= i_intf_axi_rdata;
        end
    end
end

// Parse state from output registers
logic is_idle, read_req_active, write_req_active, write_req_ending, read_req_ending;
always_comb begin 
    read_req_active = (o_intf_axi_arvalid || o_intf_axi_rready);
    read_req_ending = (o_intf_axi_rready && i_intf_axi_rvalid);

    write_req_active = (o_intf_axi_awvalid || o_intf_axi_wdvalid || o_intf_axi_bready);
    write_req_ending = (o_intf_axi_bready && i_intf_axi_bvalid);

    is_idle = (!read_req_active && !write_req_active);
end

typedef enum logic [1:0] { 
    AXI_NOP,
    AXI_W,
    AXI_L
} axi_mem_op_t;

always_comb begin
    // Constants 
    o_intf_axi_wdstrb = 4'b1111;
    o_intf_axi_awwprot = 3'b000;
    o_intf_axi_awcache = 4'b0011;
    o_intf_axi_arwprot = o_intf_axi_awwprot;
    o_intf_axi_arcache = o_intf_axi_awcache;

    // Default values
    o_rdy = 0;
    start_write_valid = 0;
    start_read_valid = 0;

    if (is_idle || write_req_ending || read_req_ending) begin 
        // Can accept operations
        o_rdy = 1;

        if (i_req.op == CBR_L) begin 
            start_read_valid = 1;
        end
        else if (i_req.op != CBR_NOP) begin
            start_write_valid = 1;
        end
    end
end

always_ff @(posedge clk) begin 
    // By default tries to go 0
    o_res.done <= 0;
    // Write starting signal done
    if (start_write_valid) begin 
        o_res.done <= 1;
    end
    // Read ending, also signal done
    if (read_req_ending) begin 
        o_res.done <= 1;
    end
end


endmodule

