// Based on non ratified spec 
// https://tools.cloudbear.ru/docs/riscv-aclint-1.0-20220110.pdf

module rv_aclint 
import triciclo_pkg::*;
# (
    parameter int NHARTS = 1
)
(
    input logic clk, resetn,

    input cbr_req_t i_req,
    output logic o_rdy,
    output cbr_res_t o_res,

    output logic o_mtip [NHARTS - 1:0],
    output logic o_msip [NHARTS - 1:0],

    // IO for csr access mode...
    output logic [63:0] o_mtime
);

localparam int HART_ID_BITS = clamp0($clog2(NHARTS) - 1);

// Address decoding
logic [1:0] target_regs;
logic [HART_ID_BITS:0] target_hart;

/* verilator lint_off UNUSEDSIGNAL */
// 3 bits for 8 B regs
logic [2:0] target_byte;
/* verilator lint_on UNUSEDSIGNAL */

always_comb begin 
    target_regs = i_req.addr[16:15];
    target_byte = i_req.addr[2:0];

    case (target_regs)
        // mtime mtimecmp, 64 bytes
        0, 1: begin 
            target_hart = i_req.addr[HART_ID_BITS + 3:3];
        end
        // msip, ssip, 32 bytes
        2, 3: begin 
            target_hart = i_req.addr[HART_ID_BITS + 2:2];
            target_byte[2] = 0;
        end
    endcase
end

// Always ready
always_comb begin 
    o_rdy = 1;
end

// Time counter register
logic [1:0][3:0][7:0] mtime;
// Time compare registers
logic [NHARTS - 1:0][1:0][3:0][7:0] mtimecmp;

// Timer interrupt logic
always_comb begin
    o_mtime = mtime;

    for (int i = 0; i < NHARTS; i += 1) begin 
        o_mtip[i] = mtime >= mtimecmp[i];
    end
end

always_ff @(posedge clk) begin
    if (!resetn) o_res.done <= 0;
    else if (i_req.op != CBR_NOP) o_res.done <= 1;
    else o_res.done <= 0;
end

always_ff @(posedge clk) begin 
    if (i_req.op == CBR_L) begin
        // default 0s
        o_res.data <= 0;

        if (target_regs == 0) o_res.data <= mtime[target_byte[2]];
        else if (target_regs == 1) o_res.data <= mtimecmp[target_hart][target_byte[2]];
        else if (target_regs == 2) o_res.data[0] <= o_msip[target_hart];
    end
end

// Atm only supports word write
// TODO byte level write

always_ff @(posedge clk) begin
    if (!resetn) mtime <= 0;
    else if (i_req.op == CBR_SW && target_regs == 0) mtime[target_byte[2]] <= i_req.data;
    else mtime <= mtime + 1;
end

always_ff @(posedge clk) begin
    if (!resetn) for (int i = 0; i < NHARTS; i += 1) mtimecmp[i] <= 0;
    else if (i_req.op == CBR_SW && target_regs == 1) mtimecmp[target_hart][target_byte[2]] <= i_req.data;
end

always_ff @(posedge clk) begin
    if (!resetn) for (int i = 0; i < NHARTS; i += 1) o_msip[i] <= 0;
    else if (i_req.op == CBR_SW && target_regs == 2) o_msip[target_hart] <= i_req.data[0];
end

endmodule;
