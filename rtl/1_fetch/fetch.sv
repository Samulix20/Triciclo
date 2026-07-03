module fetch 
import triciclo_pkg::*;
(
    input logic clk, resetn, enable,
    
    input logic exec_pb,

    // Instr Bus
    output mem_request_t instr_req,
    input logic req_ack,

    // Pipeline
    input logic dec_ready,
    output fetch_dec_buff_t fetch_dec_buff,

    /* verilator lint_off UNUSEDSIGNAL */
    input flush_bus_t flush_bus
    /* verilator lint_on UNUSEDSIGNAL */
);

l32 pc, pc4;
assign pc4 = pc + 4;

l32 pb_pc, pb_pc4;
assign pb_pc4 = pb_pc + 4;

logic exec_pb_prev;
logic exec_pb_rising;
assign exec_pb_rising = exec_pb && !exec_pb_prev;

l32 fetch_addr;
assign fetch_addr = exec_pb ? pb_pc : pc;

always_comb begin 
    instr_req.addr = fetch_addr;
    instr_req.data = 0;

    if (dec_ready && enable) instr_req.op = MEM_LW;
    else instr_req.op = MEM_NOP;
end

logic fetch_done;
assign fetch_done = req_ack && dec_ready;

always_ff @(posedge clk) begin
    if (!resetn) begin 
        pc <= RESET_PC;
        pb_pc <= 0;
        exec_pb_prev <= 0;
        fetch_dec_buff.valid <= 0;
    end
    else if (enable) begin
        exec_pb_prev <= exec_pb;

        if (flush_bus.op != NO_FLUSH) begin 
            pc <= flush_bus.to;
            fetch_dec_buff.valid <= 0;
        end
        else if (exec_pb_rising) begin
            // Reset de la ejecución del pb
            pb_pc <= 0;
            fetch_dec_buff.valid <= 0;
        end
        else if (fetch_done) begin 
            if (exec_pb) pb_pc <= pb_pc4;
            else pc <= pc4;
            fetch_dec_buff.valid <= 1;
        end
    end
end


endmodule
