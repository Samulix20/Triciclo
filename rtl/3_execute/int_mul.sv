// 32 bit integer multiplication unit

module int_mul
import triciclo_pkg::*;
(
    input logic clk,

    input l32 op1, op2,
    input mul_op_t opsel,
    output l32 result,

    // Control for multicycle
    input logic set_ops, do_mul
);

// Registers for 32 bit multiplier
logic result_neg_reg;
l32 mul_op1, mul_op2;
l64 mul_result;

// Decode operation combinational signals
logic op1_neg, op2_neg, result_neg, get_upper;
l64 final_mul_result;

always_comb begin 
    op1_neg = op1[31];
    op2_neg = op2[31];
    get_upper = 0;

    unique case(opsel)
        MUL_OP_MULHSU: begin
            // High Signed x Unsigned
            op2_neg = 0;
            get_upper = 1;
        end

        MUL_OP_MULHU: begin
            // High Unsigned mul
            op1_neg = 0;
            op2_neg = 0;
            get_upper = 1;
        end

        MUL_OP_MULH: begin 
            // High signed mul
            get_upper = 1;
        end

        default: begin end
    endcase

    result_neg = op1_neg ^ op2_neg;

    if (result_neg_reg) final_mul_result = (~mul_result) + 1;
    else final_mul_result = mul_result;

    if (get_upper) result = final_mul_result[1];
    else result = final_mul_result[0];
end


always_ff @(posedge clk) begin
    // 1 st cycle
    if (set_ops) begin
        if (op1_neg) mul_op1 <= (~op1) + 1;
        else mul_op1 <= op1;

        if (op2_neg) mul_op2 <= (~op2) + 1;
        else mul_op2 <= op2;

        result_neg_reg <= result_neg;
    end

    // 2 nd cycle
    if (do_mul) mul_result <= mul_op1 * mul_op2;
end

endmodule
