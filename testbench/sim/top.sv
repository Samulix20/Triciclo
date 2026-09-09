
/* verilator lint_off UNUSEDSIGNAL */

`include "axi4_lite.svh"

module top
import icb_pkg::*;
import triciclo_pkg::*;
(
    input logic clk, resetn
);

localparam int fast_net_len = 5;
localparam logic [fast_net_len - 1:0][pma_conf_size - 1:0] fast_net_conf = {
    32'hFF00_0000, 32'h0c00_0000,
    32'hFF00_0000, 32'h0200_0000,
    32'hF000_0000, 32'h1000_0000,
    32'hF000_0000, 32'h2000_0000,
    32'hFC00_0000, 32'h8000_0000  // DRAM, 64 MiB (matches testbench.cpp's dpi_mem_size)
};

logic meip, mtip, msip;
l64 mtime_val;

icb_if #(.ADDR_W(32), .DATA_W(32), .OP_W(4)) iport_bus ();
icb_if #(.ADDR_W(32), .DATA_W(32), .OP_W(4)) dport_bus ();

triciclo  # (
    .HARDTID(0),
    .PMA_REGS(fast_net_len), .PMA_CONF(fast_net_conf)
) core (
    .clk(clk), .resetn(resetn), .enable(1),
    // IRQs
    .mtip(mtip), .msip(0), .meip(meip),
    // Instruction
    .iport(iport_bus),
    // Data
    .dport(dport_bus)
);

// Instruction memory

localparam int ifetch_net_len = 1;
localparam logic [ifetch_net_len - 1:0][pma_conf_size - 1:0] ifetch_net_conf = {
    32'hFC00_0000, 32'h8000_0000  // DRAM, 64 MiB (matches testbench.cpp's dpi_mem_size)
};

icb_if #(.ADDR_W(32), .DATA_W(32), .OP_W(4)) ifetch_net_array [ifetch_net_len] ();

icb_net #(
    .NSLAVES(ifetch_net_len),
    .PMA_CONF(ifetch_net_conf)
) ifetch_net (
    .clk(clk), .resetn(resetn),
    .mst(iport_bus),
    .slv(ifetch_net_array)
);

dpi_amo_mem main_instruction_memory (
    .clk(clk), .resetn(resetn),
    .slv(ifetch_net_array[0])
);

// Fast Net
icb_if #(.ADDR_W(32), .DATA_W(32), .OP_W(4)) fast_net_array [fast_net_len] ();

icb_net #(
    .NSLAVES(fast_net_len),
    .PMA_CONF(fast_net_conf)
) fast_net (
    .clk(clk), .resetn(resetn),
    .mst(dport_bus),
    .slv(fast_net_array)
);

logic [31:0] plic_pending;
logic uart_irq;

always_comb begin
    plic_pending = 0;
    plic_pending[3] = uart_irq;
end

rv_plic plic (
    .clk(clk), .resetn(resetn),
    .pending(plic_pending), .meip(meip),
    .slv(fast_net_array[4])
);

rv_clint clint (
    .clk(clk), .resetn(resetn),
    .o_mtip(mtip), .o_msip(msip), .o_mtime(mtime_val),
    .slv(fast_net_array[3])
);

icb_dpi_slv general_mmio (
    .clk(clk), .resetn(resetn),
    .slv(fast_net_array[2])
);

dpi_sifive_uart sifive_uart (
    .clk(clk), .resetn(resetn), .irq(uart_irq),
    .slv(fast_net_array[1])
);

dpi_amo_mem main_data_memory (
    .clk(clk), .resetn(resetn),
    .slv(fast_net_array[0])
);


endmodule

