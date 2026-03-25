
module zicsr
import triciclo_pkg::*;
(
    input l32 csr, operand,
    zicsr_op_t opsel,
    output l32 reg_result,
    output l32 csr_result
);

always_comb begin
    reg_result = csr;
    case (opsel)
        CSR_RW: begin
            csr_result = operand;
        end
        CSR_RS: begin 
            csr_result = csr | operand;
        end
        CSR_RC: begin
            csr_result = csr & (~operand);
        end
        default: csr_result = csr; 
    endcase
end

endmodule
