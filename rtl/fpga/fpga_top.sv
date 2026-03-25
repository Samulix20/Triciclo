
/* verilator lint_off UNUSEDSIGNAL */

`include "axi4_lite.svh"

module fpga_top
import triciclo_pkg::*;
(
    input logic clk, resetn,

    // slv_reg0, 1, 2
    input logic [31:0] fpga_ctrl_reg, fpga_mem_addr, fpga_mem_data,

    output logic core_data_write, core_exit,
    output logic [31:0] core_data_reg
);

localparam int unsigned NHARTS = 1;

// Data master requests
cbr_req_t master_req [1];
cbr_res_t master_res [1];
logic master_ack [1];

// Instruction bus requests
cbr_req_t instr_req;
cbr_res_t instr_res;
logic instr_ack;

// Accepted operation so it can be observed
cbr_req_t accepted_op;

cbr_req_t fpga_mem_req;
always_comb begin
    fpga_mem_req.addr = fpga_mem_addr;
    fpga_mem_req.data = fpga_mem_data;
    // Store or load
    if (fpga_ctrl_reg[2:1] == 'b01) fpga_mem_req.op = CBR_L;
    else if (fpga_ctrl_reg[2:1] == 'b10) fpga_mem_req.op = CBR_SW;
    else fpga_mem_req.op = CBR_NOP;
end

// Mux that controls the instruction port
// The FPGA can take control
cbr_req_t final_instr_req;
always_comb begin 
    if (!fpga_ctrl_reg[0]) final_instr_req = fpga_mem_req;
    else final_instr_req = instr_req;
end

l64 mtime;
logic mtip [1], msip [1];

triciclo  # (
    .HARDTID(0)
) core (
    .clk(clk), .resetn(resetn), .enable(fpga_ctrl_reg[0]),
    // Instruction
    .instr_req(instr_req),
    .instr_req_ack(instr_ack),
    .instr_res(instr_res),
    // Data
    .data_req(master_req[0]),
    .data_req_ack(master_ack[0]),
    .data_res(master_res[0]),
    // IRQs
    .mtip(mtip[0]), .msip(msip[0]), .meip(0)
);

// Core Bus memory map and regions
localparam int unsigned FPGA_DEBUG_ADDR = 'h10600000;
localparam int unsigned FPGA_CTRL_ADDR = 'h10600010;
localparam int unsigned FPGA_EXIT_ADDR = 'h10601000;
localparam int unsigned DRAM_SIZE_KB = 128;

// Core Bus memory map and regions
localparam int unsigned NREGIONS = 3;
localparam logic [31:0] ADDR_RANGES [2 * NREGIONS] = {
    'h1000_0000,
    'h1FFF_FFFF,
    
    'h2000_0000,
    'h2FFF_FFFF,

    'h8000_0000,
    'hFFFF_FFFF
};
localparam int unsigned NSLAVES = 3;
localparam int SLAVE_ID_BITS = $clog2(NSLAVES);
localparam logic [SLAVE_ID_BITS - 1: 0] REGION_SLAVE_MAP [NREGIONS] = {
    0, 
    1,
    2
};

cbr_req_t slaves_reqs [NSLAVES];
cbr_res_t slaves_resp [NSLAVES];
logic slaves_rdys [NSLAVES];

core_bus #(
    .NREGIONS(NREGIONS),
    .ADDR_RANGES(ADDR_RANGES),
    .NSLAVES(NSLAVES),
    .REGION_SLAVE_MAP(REGION_SLAVE_MAP),
    .NMASTERS(NHARTS)
) fast_bus (
    .clk(clk), .resetn(resetn),

    .i_ms_req(master_req),
    .o_ms_rdy(master_ack),
    .o_ms_res(master_res),

    .o_slv_req(slaves_reqs),
    .i_slv_res(slaves_resp),
    .i_slv_rdy(slaves_rdys),

    .o_accepted_op(accepted_op)
);

fpga_debug # (
    .DATA_ADDR(FPGA_DEBUG_ADDR),
    .CTRL_ADDR(FPGA_CTRL_ADDR),
    .EXIT_ADDR(FPGA_EXIT_ADDR)
) fpga_debug (
    .clk(clk), .resetn(resetn),

    .bus_req(slaves_reqs[0]),
    .bus_rdy(slaves_rdys[0]),
    .bus_res(slaves_resp[0]),

    .ctrl_reg(fpga_ctrl_reg),
    .core_data_write(core_data_write), .o_data(core_data_reg),
    .core_exit(core_exit)
);

rv_aclint aclint (
    .clk(clk), .resetn(resetn),

    .i_req(slaves_reqs[1]),
    .o_rdy(slaves_rdys[1]),
    .o_res(slaves_resp[1]),

    .o_mtip(mtip),
    .o_msip(msip),

    .o_mtime(mtime)
);

memory_4_banks #(
    .SIZE_KB(DRAM_SIZE_KB)
) main_mem (
    .clk(clk), .resetn(resetn),

    .i_instr_req(final_instr_req),
    .o_instr_rdy(instr_ack),
    .o_instr_res(instr_res),

    .i_data_req(slaves_reqs[2]),
    .o_data_rdy(slaves_rdys[2]),
    .o_data_res(slaves_resp[2])
);

endmodule

