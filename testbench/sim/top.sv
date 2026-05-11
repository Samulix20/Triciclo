
/* verilator lint_off UNUSEDSIGNAL */

`include "icb.svh"
`include "axi4_lite.svh"

module top
import icb_pkg::*;
import triciclo_pkg::*;
(
    input logic clk, resetn
);

// Normally controlled by PLIC
logic meip_irq /* verilator public */;
assign meip_irq = 0;

localparam int unsigned NHARTS = 1;
logic mtip [NHARTS - 1:0];
logic msip [NHARTS - 1:0];
l64 mtime_val;

`ICB_BUS(iport_bus, 32, 32, 4, 1);
`ICB_BUS(dport_bus, 32, 32, 4, 1);

triciclo  # (
    .HARDTID(0)
) core (
    .clk(clk), .resetn(resetn), .enable(1),
    // Instruction
    `ICB_BUS_CONNECT(iport, iport_bus),
    // Data
    `ICB_BUS_CONNECT(dport, dport_bus),
    // IRQs
    .mtip(mtip[0]), .msip(msip[0]), .meip(0)
);

// Instruction memory

amo_mem main_instruction_memory (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT(slv, iport_bus)
);

// Fast Net

localparam int pma_conf_size = 32 * 2;
localparam int fast_net_len = 4;
localparam logic [fast_net_len - 1:0][pma_conf_size - 1:0] fast_net_conf = {
    32'hF000_0000, 32'h1000_0000,
    32'hF000_0000, 32'h2000_0000,
    32'hF000_0000, 32'h3000_0000,
    32'h8000_0000, 32'h8000_0000
};

`ICB_BUS_ARRAY(fast_net_array, fast_net_len, 32, 32, 4, 1);

icb_net #(
    .NSLAVES(fast_net_len),
    .PMA_CONF(fast_net_conf)
) fast_net (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT(mst, dport_bus),
    `ICB_BUS_CONNECT(slv, fast_net_array)
);

amo_mem main_data_memory (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT_ARRAY(slv, fast_net_array, 0)
);

rv_aclint aclint (
    .clk(clk), .resetn(resetn),
    .o_mtip(mtip), .o_msip(msip), .o_mtime(mtime_val),
    `ICB_BUS_CONNECT_ARRAY(slv, fast_net_array, 2)
);

icb_dpi_slv general_mmio (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT_ARRAY(slv, fast_net_array, 3)
);

`AXI4_LITE_BUS(axi_bus, 32, 32, 4);

axi4_lite_master axi_mst (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT_ARRAY(slv, fast_net_array, 1),
    `AXI4_LITE_MASTER_CONNECT(axi_bus, intf)
);

axi4_lite_slave axi_slv (
    .i_clk(clk), .i_resetn(resetn),
    `AXI4_LITE_SLAVE_CONNECT(axi_bus, intf)
);

endmodule

