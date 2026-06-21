/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */

`include "icb.svh"

module triciclo 
import triciclo_pkg::*;
import icb_pkg::*;
# (
    parameter int HARDTID = 0,
    parameter int PMA_REGS = 0,
    parameter     PMA_CONF = '0
)
(
    input logic clk, resetn, enable,
    // Instruction
    `ICB_BUS_MASTER_PORT(iport, 32, 32, 4),
    // Data
    `ICB_BUS_MASTER_PORT(dport, 32, 32, 4),
    // Pending interrupts
    input logic mtip, msip, meip,

    // Debug
    input  dbg_core_control_t dbg_core_control,
    output dbg_core_status_t  dbg_core_status 
);

mem_request_t instr_mem_req, data_mem_req;

always_comb begin
    mem_req_to_bus_req(instr_mem_req, iport_icb_req_valid, iport_icb_req_addr, iport_icb_req_data, iport_icb_req_wstrb, iport_icb_req_op);
    mem_req_to_bus_req(data_mem_req, dport_icb_req_valid, dport_icb_req_addr, dport_icb_req_data, dport_icb_req_wstrb, dport_icb_req_op);
end

logic dec_ready;
fetch_dec_buff_t fetch_dec_buff;

logic exec_ready;
dec_exec_buff_t dec_exec_buff;

flush_bus_t flush_bus;

rv_reg_id_t [CORE_RF_NUM_READ - 1:0] rf_read_ids;
l32 [CORE_RF_NUM_READ - 1:0] rf_data;
rf_write_request_t rf_write_req;

rv_csr_id_t csr_read_id;
l32 csr_data;
csr_write_request_t csr_req;
trap_config_t trap_conf;

logic instr_ret;


// Debug
logic halt_req, step_req, haltonr_req, resume_req, dbg_reset;
logic fetch_enable;

reg_file #(
    .NUM_READ_PORTS(CORE_RF_NUM_READ)
) rf (
    .clk(clk),
    .rs(rf_read_ids), .o(rf_data),
    .write_request(rf_write_req)
);

csr_file csr_file (
    .clk(clk), .resetn(dbg_reset), .enable(enable), .instr_ret(instr_ret),
    .read_id(csr_read_id), .read_csr(csr_data),
    .csr_write_req(csr_req),
    .trap_conf(trap_conf),
    .flush_bus(flush_bus)
);

fetch fetch (
    .clk(clk), .resetn(dbg_reset), .enable(fetch_enable),
    .instr_req(instr_mem_req), .req_ack(iport_icb_req_ready),
    .dec_ready(dec_ready), .fetch_dec_buff(fetch_dec_buff),
    .flush_bus(flush_bus)
);

decode decode (
    .clk(clk), .resetn(dbg_reset), .enable(fetch_enable),
    .instr(iport_icb_resp_data), .instr_req_done(iport_icb_resp_valid),
    .rf_read_ids(rf_read_ids), .rf_data(rf_data),
    .csr_id(csr_read_id), .csr_data(csr_data),
    .fetch_dec_buff(fetch_dec_buff), .dec_ready(dec_ready),
    .exec_ready(exec_ready), .dec_exec_buff(dec_exec_buff),
    .current_csr_write(csr_req.write_enable), .rf_write_req(rf_write_req),
    .flush_bus(flush_bus)
);

execute execute (
    .clk(clk), .resetn(dbg_reset), .enable(enable), .instr_ret(instr_ret),
    .dec_data(dec_exec_buff), .exec_ready(exec_ready),
    .data_req(data_mem_req), .data_req_ack(dport_icb_req_ready), 
    .mem_data(dport_icb_resp_data), .data_req_done(dport_icb_resp_valid),
    .rf_req_reg(rf_write_req), .csr_req_reg(csr_req),
    .mtip(mtip), .msip(msip), .meip(meip),
    .halt_req(halt_req), .step_req(step_req), .haltonr_req(haltonr_req), .resume_req(resume_req),
    .trap_conf(trap_conf), .flush_bus(flush_bus),
    .mem_err(0)
);

dbg dbg (
    .clk              (clk),
    .resetn           (resetn),
    .dbg_core_control (dbg_core_control),
    .dbg_core_status  (dbg_core_status),
    .flush_bus        (flush_bus),
    .instr_ret        (instr_ret),
    .trap_conf        (trap_conf),
    .halt_req         (halt_req),
    .step_req         (step_req),
    .haltonr_req      (haltonr_req),
    .resume_req       (resume_req),
    .dbg_reset        (dbg_reset),
    .fetch_enable     (fetch_enable)
);

endmodule
