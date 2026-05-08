
// TODO example for test that divides in 1 cycle
// Non implementable in FPGA

module int_div
import triciclo_pkg::*;
(
    input l32 op1, op2,
    input div_op_t opsel,
    output l32 result
);

logic most_neg;

always_comb begin 
    most_neg = (op1[31] == 1 && op1[30:0] == 0);

    case (opsel)
        DIV_OP_DIV: begin
            if (op2 == 0) result = -1; 
            else if (most_neg && $signed(op2) == -1) result = op1;
            else result = $signed(op1) / $signed(op2);
        end
        DIV_OP_DIVU: begin 
            if (op2 == 0) result = 'hFFFFFFFF;
            else result = $unsigned(op1) / $unsigned(op2);
        end 
        DIV_OP_REM: begin 
            if (op2 == 0) result = op1;
            else result = $signed(op1) % $signed(op2);
        end
        DIV_OP_REMU: begin 
            if (op2 == 0) result = op1;
            else result = $unsigned(op1) % $unsigned(op2);
        end
    endcase
end

endmodule
