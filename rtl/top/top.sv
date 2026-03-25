
/* verilator lint_off UNUSEDSIGNAL */

`include "axi4_lite.svh"

module top
import triciclo_pkg::*;
(
    input logic clk, resetn
);

// Normally controlled by PLIC
logic meip_irq /* verilator public */;
assign meip_irq = 0;

l64 mtime_val;

localparam int unsigned NHARTS = 1;

logic mtip [NHARTS - 1:0];
logic msip [NHARTS - 1:0];

// Data master requests
cbr_req_t master_req [NHARTS];
cbr_res_t master_res [NHARTS];
logic master_ack [NHARTS];

// Instruction bus requests
cbr_req_t instr_req [NHARTS];
cbr_res_t instr_res [NHARTS];
logic instr_ack [NHARTS];

// Accepted operation
cbr_req_t accepted_op;
logic observe_store;
l32 observe_store_addr;

always_comb begin 
    observe_store_addr = accepted_op.addr;
    observe_store = (accepted_op.op != CBR_NOP && accepted_op.op != CBR_L);
end

triciclo  # (
    .HARDTID(0)
) core (
    .clk(clk), .resetn(resetn), .enable(1),
    // Instruction
    .instr_req(instr_req[0]),
    .instr_req_ack(instr_ack[0]),
    .instr_res(instr_res[0]),
    // Data
    .data_req(master_req[0]),
    .data_req_ack(master_ack[0]),
    .data_res(master_res[0]),
    // IRQs
    .mtip(mtip[0]), .msip(msip[0]), .meip(0)
);

// FAST BUS

// Core Bus memory map and regions
localparam int unsigned NREGIONS = 3;
localparam logic [31:0] ADDR_RANGES [2 * NREGIONS] = {
    'h0000_1000,
    'h0000_1FFF,
    
    'h1000_0000,
    'h7FFF_FFFF,

    'h8000_0000,
    'hFFFF_FFFF
};
localparam int unsigned NSLAVES = 3;
localparam int SLAVE_ID_BITS = $clog2(NSLAVES);
localparam logic [SLAVE_ID_BITS - 1: 0] REGION_SLAVE_MAP [NREGIONS] = {
    0, 
    1,
    0
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

/* verilator lint_off PINMISSING */
memory_dpi mem (
    .clk(clk), .resetn(resetn),

    .i_data_req(slaves_reqs[0]),
    .o_data_rdy(slaves_rdys[0]),
    .o_data_res(slaves_resp[0]),

    .i_instr_req(instr_req[0]),
    .o_instr_rdy(instr_ack[0]),
    .o_instr_res(instr_res[0])
);
/* verilator lint_on PINMISSING */

cbr_req_t slow_bus_master_req [1];
cbr_res_t slow_bus_master_res [1];
logic slow_bus_master_rdy [1];

bus_bridge bridge (
    .clk(clk), .resetn(resetn),

    .slave_port_req(slaves_reqs[1]),
    .slave_port_rdy(slaves_rdys[1]),
    .slave_port_res(slaves_resp[1]),

    .master_port_req(slow_bus_master_req[0]),
    .master_port_rdy(slow_bus_master_rdy[0]),
    .master_port_res(slow_bus_master_res[0])
);

// SLOW BUS

localparam int unsigned SLOW_REGIONS = 3;
localparam logic [31:0] SLOW_ADDR_RANGES [2 * NREGIONS] = {
    'h1000_0000,
    'h1FFF_FFFF,

    'h2000_0000,
    'h2FFF_FFFF,

    'h7000_0000,
    'h7FFF_FFFF
};

localparam int unsigned SLOW_NSLAVES = 3;
localparam int SLOW_SLAVE_ID_BITS = $clog2(SLOW_NSLAVES);
localparam logic [SLOW_SLAVE_ID_BITS - 1: 0] SLOW_REGION_SLAVE_MAP [SLOW_REGIONS] = {
    0,
    1,
    2
};

cbr_req_t slow_bus_slaves_reqs [SLOW_REGIONS];
cbr_res_t slow_bus_slaves_resp [SLOW_REGIONS];
logic slow_bus_slaves_rdys [SLOW_REGIONS];

/* verilator lint_off PINMISSING */
core_bus #(
    .NREGIONS(SLOW_REGIONS),
    .ADDR_RANGES(SLOW_ADDR_RANGES),
    .NSLAVES(SLOW_NSLAVES),
    .REGION_SLAVE_MAP(SLOW_REGION_SLAVE_MAP),
    .NMASTERS(1)
) slow_bus (
    .clk(clk), .resetn(resetn),

    .i_ms_req(slow_bus_master_req),
    .o_ms_rdy(slow_bus_master_rdy),
    .o_ms_res(slow_bus_master_res),

    .o_slv_req(slow_bus_slaves_reqs),
    .i_slv_res(slow_bus_slaves_resp),
    .i_slv_rdy(slow_bus_slaves_rdys)
);
/* verilator lint_on PINMISSING */

mmio_dpi mmio (
    .clk(clk), .resetn(resetn),

    .i_req(slow_bus_slaves_reqs[0]),
    .o_rdy(slow_bus_slaves_rdys[0]),
    .o_res(slow_bus_slaves_resp[0])
);

rv_aclint aclint (
    .clk(clk), .resetn(resetn),

    .i_req(slow_bus_slaves_reqs[1]),
    .o_rdy(slow_bus_slaves_rdys[1]),
    .o_res(slow_bus_slaves_resp[1]),

    .o_mtip(mtip),
    .o_msip(msip),

    .o_mtime(mtime_val)
);

`AXI4_LITE_BUS(bus, 32, 32, 4);

axi4_lite_master axi_ms (
    .clk(clk), .resetn(resetn),

    .i_req(slow_bus_slaves_reqs[2]),
    .o_rdy(slow_bus_slaves_rdys[2]),
    .o_res(slow_bus_slaves_resp[2]),

    `AXI4_LITE_MASTER_CONNECT(bus, intf)
);

axi4_lite_slave axi_slv (
    .i_clk(clk), .i_resetn(resetn),

    `AXI4_LITE_SLAVE_CONNECT(bus, intf)
);

endmodule

