/* verilator lint_off UNUSEDSIGNAL */

module memory_dpi 
import triciclo_pkg::*;
(
    input logic clk, resetn,

    input cbr_req_t i_data_req,
    output logic o_data_rdy,
    output cbr_res_t o_data_res,

    input cbr_req_t i_instr_req,
    output logic o_instr_rdy,
    output cbr_res_t o_instr_res
);

logic [3:0][7:0] bytes_to_write; 
logic [3:0] wstrbs;

always_comb begin 

    wstrbs = '{default: 0};

    unique case (i_data_req.op)
        CBR_SW: begin 
            wstrbs = '{default: 1};
            bytes_to_write = i_data_req.data;
        end

        CBR_SH: begin 
            wstrbs = 4'b0011;
            bytes_to_write[1:0] = i_data_req.data[15:0];
            if (i_data_req.addr[1]) begin 
                wstrbs = wstrbs << 2;
                bytes_to_write = bytes_to_write << 16;
            end
        end

        CBR_SB: begin 
            wstrbs[i_data_req.addr[1:0]] = 1;
            bytes_to_write[i_data_req.addr[1:0]] = i_data_req.data[7:0];
        end

        default: begin end
    endcase

end

// Always ready
always_comb begin 
    o_data_rdy = 1;
    o_instr_rdy = 1;
end

import "DPI-C" function void dpi_mem_store_byte(int addr, int idx, int data);
import "DPI-C" function int dpi_mem_load(int addr);

always_ff @(posedge clk) begin 

    if (i_data_req.op == CBR_L) begin
        o_data_res.data <= dpi_mem_load(i_data_req.addr);
    end
    
    for (int i = 0; i < 4; i += 1) begin 
        if (wstrbs[i]) begin 
            dpi_mem_store_byte(i_data_req.addr, int'(i), int'(bytes_to_write[i]));
        end
    end

    // Handshake
    if (!resetn) begin 
        o_data_res.done <= 0;
    end
    else if (i_data_req.op != CBR_NOP && o_data_rdy) begin 
        o_data_res.done <= 1;
    end
    else begin 
        o_data_res.done <= 0;
    end

end


always_ff @(posedge clk) begin 

    if (i_instr_req.op == CBR_L) begin
        o_instr_res.data <= dpi_mem_load(i_instr_req.addr);
    end

    // Handshake
    if (!resetn) begin 
        o_instr_res.done <= 0;
    end
    else if (i_instr_req.op != CBR_NOP && o_instr_rdy) begin 
        o_instr_res.done <= 1;
    end
    else begin 
        o_instr_res.done <= 0;
    end

end

endmodule;
