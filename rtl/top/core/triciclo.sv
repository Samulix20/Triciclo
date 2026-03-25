/* verilator lint_off UNUSEDPARAM */

module triciclo 
import triciclo_pkg::*;
# (
    parameter int HARDTID = 0
)
(
    input logic clk, resetn, enable,

    // Instruction req port
    output cbr_req_t instr_req,
    input logic instr_req_ack,
    input cbr_res_t instr_res,

    // Data req port
    output cbr_req_t data_req,
    input logic data_req_ack,
    input cbr_res_t data_res,

    // Pending interrupts
    input logic mtip, msip, meip
);

mem_request_t instr_mem_req, data_mem_req;

always_comb begin
    mem_req_to_bus_req(instr_mem_req, instr_req);
    mem_req_to_bus_req(data_mem_req, data_req);
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
trap_type_t trap_type;

logic instr_ret;

reg_file #(
    .NUM_READ_PORTS(CORE_RF_NUM_READ)
) rf (
    .clk(clk),
    .rs(rf_read_ids), .o(rf_data),
    .write_request(rf_write_req)
);

csr_file csr_file (
    .clk(clk), .resetn(resetn), .enable(enable), .instr_ret(instr_ret),
    .read_id(csr_read_id), .read_csr(csr_data),
    .csr_write_req(csr_req),
    .trap_conf(trap_conf),
    .trap_type(trap_type),
    .flush_bus(flush_bus)
);

fetch fetch (
    .clk(clk), .resetn(resetn), .enable(enable),
    .instr_req(instr_mem_req), .req_ack(instr_req_ack),
    .dec_ready(dec_ready), .fetch_dec_buff(fetch_dec_buff),
    .flush_bus(flush_bus)
);

decode decode (
    .clk(clk), .resetn(resetn), .enable(enable),
    .instr(instr_res.data), .instr_req_done(instr_res.done),
    .rf_read_ids(rf_read_ids), .rf_data(rf_data),
    .csr_id(csr_read_id), .csr_data(csr_data),
    .fetch_dec_buff(fetch_dec_buff), .dec_ready(dec_ready),
    .exec_ready(exec_ready), .dec_exec_buff(dec_exec_buff),
    .current_csr_write(csr_req.write_enable), .rf_write_req(rf_write_req),
    .flush_bus(flush_bus)
);

execute execute (
    .clk(clk), .resetn(resetn), .enable(enable), .instr_ret(instr_ret),
    .dec_data(dec_exec_buff), .exec_ready(exec_ready),
    .data_req(data_mem_req), .data_req_ack(data_req_ack), .mem_data(data_res.data), .data_req_done(data_res.done),
    .rf_req_reg(rf_write_req), .csr_req_reg(csr_req),
    .mtip(mtip), .msip(msip), .meip(meip),
    .trap_conf(trap_conf), .trap(trap_type),
    .flush_bus(flush_bus)
);

endmodule
