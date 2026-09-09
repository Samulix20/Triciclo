
/* verilator lint_off UNUSEDSIGNAL */

module branch
import triciclo_pkg::*;
#(
    parameter int PMA_REGS = 1,
    parameter logic [PMA_REGS - 1:0][pma_conf_size - 1:0] PMA_CONF = 0
) (
    input l32 op1, op2, target,
    input branch_op_t branch_op,
    output logic do_branch, ma, pma_fault,
    output l32 branch_target
);

logic eq, lt, ltu;

// Comparators
always_comb begin
    eq = (op1 == op2);
    lt = ($signed(op1) < $signed(op2));
    ltu = (op1 < op2);
end

// Branch decision
always_comb begin
    case (branch_op)
        OP_BEQ: do_branch = eq;
        OP_BNE: do_branch = ~eq;
        OP_BLT: do_branch = lt;
        OP_BGE: do_branch = ~lt;
        OP_BLTU: do_branch = ltu;
        OP_BGEU: do_branch = ~ltu;
        OP_J: do_branch = 1;
        default: do_branch = 0;
    endcase
end

// JALR requires clearing bit 0 of the computed target
// Harmless for JAL/conditional branches, whose immediates always have bit 0 = 0.
assign branch_target = {target[31:1], 1'b0};

// PMA Check
logic internal_pma_fault;
pma_check #(
    .PMA_REGS(PMA_REGS), .PMA_CONF(PMA_CONF)
) pma_check (
    .addr(branch_target), .fault(internal_pma_fault)
);

always_comb begin
    ma = (do_branch && branch_target[1:0] != 0);
    pma_fault = (do_branch && internal_pma_fault);
end



endmodule
