/* verilator lint_off UNUSEDSIGNAL */

`include "icb.svh"
`include "axi4_lite.svh"

module top
import icb_pkg::*;
import triciclo_pkg::*;
(
    input logic clk, resetn,

    input dbg_core_control_t dbg_core_control,
    output dbg_core_status_t  dbg_core_status
);

localparam int fast_net_len = 5;
localparam logic [fast_net_len - 1:0][pma_conf_size - 1:0] fast_net_conf = {
    32'hFF00_0000, 32'h0c00_0000,
    32'hFF00_0000, 32'h0200_0000,
    32'hF000_0000, 32'h1000_0000,
    32'hF000_0000, 32'h2000_0000,
    32'h8000_0000, 32'h8000_0000
};

// parámetros para el icb de instrucciones
localparam int instr_net_len = 2; // 2 Esclavos: 0 = Program Buffer, 1 = Memoria Principal
localparam logic [instr_net_len - 1:0][pma_conf_size - 1:0] instr_net_conf = {
    // Estructura: {Máscara, Dirección Base}
    32'hFFF0_0000, 32'h8000_0000,  // Índice memoria principal
    32'hFFFF_F000, 32'h0000_0000   // Índice Program Buffer
};



logic meip, mtip, msip;
l64 mtime_val;

`ICB_BUS(iport_bus, 32, 32, 4);
`ICB_BUS(dport_bus, 32, 32, 4);

triciclo  # (
    .HARDTID(0),
    .PMA_REGS(fast_net_len), .PMA_CONF(fast_net_conf)
) core (
    .clk(clk), .resetn(resetn), .enable(1),
    // IRQs
    .mtip(mtip), .msip(0), .meip(meip),
    // Debug
    .dbg_core_control(dbg_core_control), .dbg_core_status(dbg_core_status),
    // Instruction
    `ICB_BUS_CONNECT(iport, iport_bus),
    // Data
    `ICB_BUS_CONNECT(dport, dport_bus)
);

// Instruction memory
`ICB_BUS_ARRAY(instr_net_array, instr_net_len, 32, 32, 4);

icb_net #(
    .NSLAVES(instr_net_len),
    .PMA_CONF(instr_net_conf)
) instr_net (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT(mst, iport_bus),          // Entrada desde el core
    `ICB_BUS_CONNECT(slv, instr_net_array)     // Salidas hacia las memorias
);


// Program buffer
dbg_write_request_t pb_dm_write_unused;
assign pb_dm_write_unused = '0;

logic [7:0] pb_dm_read_id_unused;
assign pb_dm_read_id_unused = '0;

l32 pb_dm_read_data_unused;

program_buffer dbg_program_buffer (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT_ARRAY(slv, instr_net_array, 0),
    .dm_write(pb_dm_write_unused),
    .dm_read_id(pb_dm_read_id_unused),
    .dm_read_data(pb_dm_read_data_unused)
);


amo_mem main_instruction_memory (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT_ARRAY(slv, instr_net_array, 1)
);

// Fast Net
`ICB_BUS_ARRAY(fast_net_array, fast_net_len, 32, 32, 4);

icb_net #(
    .NSLAVES(fast_net_len),
    .PMA_CONF(fast_net_conf)
) fast_net (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT(mst, dport_bus),
    `ICB_BUS_CONNECT(slv, fast_net_array)
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
    `ICB_BUS_CONNECT_ARRAY(slv, fast_net_array, 4)
);

rv_clint clint (
    .clk(clk), .resetn(resetn),
    .o_mtip(mtip), .o_msip(msip), .o_mtime(mtime_val),
    `ICB_BUS_CONNECT_ARRAY(slv, fast_net_array, 3)
);

icb_dpi_slv general_mmio (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT_ARRAY(slv, fast_net_array, 2)
);

dpi_sifive_uart sifive_uart (
    .clk(clk), .resetn(resetn), .irq(uart_irq),
    `ICB_BUS_CONNECT_ARRAY(slv, fast_net_array, 1)
);

amo_mem main_data_memory (
    .clk(clk), .resetn(resetn),
    `ICB_BUS_CONNECT_ARRAY(slv, fast_net_array, 0)
);


// always_comb begin
//     dbg_core_control <= '0;
//     dbg_core_control.resumeACK <= 1;  // reposo: bloqueado
// end

endmodule
