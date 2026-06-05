module pma_check
import triciclo_pkg::*;
#(
    parameter int PMA_REGS = 1,
    parameter logic [PMA_REGS - 1:0][pma_conf_size - 1:0] PMA_CONF = 0
) (
    input l32 addr,
    output logic fault
);

pma_conf_t [PMA_REGS - 1:0] conf;
assign conf = PMA_CONF;

always_comb begin 
    fault = 1;
    for (int i = 0; i < PMA_REGS; i += 1) begin 
        if ((addr & conf[i].mask) == conf[i].match) fault = 0;
    end
end

endmodule
