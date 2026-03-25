/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off WIDTHEXPAND */

module memory_4_banks
import triciclo_pkg::*;
#(
    parameter int SIZE_KB /*verilator public*/
)
(
    input logic clk, resetn,
    // PORT A
    input cbr_req_t i_instr_req,
    output logic o_instr_rdy,
    output cbr_res_t o_instr_res,
    // PORT B
    input cbr_req_t i_data_req,
    output logic o_data_rdy,
    output cbr_res_t o_data_res
);

// KB to number of 4 Byte Words
localparam NUM_WORDS /*verilator public*/ = SIZE_KB * 1024 / 4;
localparam ADDR_BITS = $clog2(NUM_WORDS);

logic [7:0] data_in_a [4];
logic [3:0] we_a;

logic [3:0][7:0] data_in_b;
logic [3:0] we_b;

logic instr_read, data_read;
always_comb begin
    // In the case of nops make sure to not read
    // Other operations are ok
    if (i_instr_req.op == CBR_NOP) instr_read = 0;
    else instr_read = 1;
    
    if (i_data_req.op == CBR_NOP) data_read = 0;
    else data_read = 1;
end

logic [ADDR_BITS - 1:0] addr_port_a, addr_port_b;
always_comb begin
    addr_port_a = i_instr_req.addr >> 2;
    addr_port_b = i_data_req.addr >> 2;
end

// Instr request -> Port A
// Handle word level access
always_comb begin 
    we_a = 0;
    data_in_a[0] = i_instr_req.data[7:0];
    data_in_a[1] = i_instr_req.data[15:8];
    data_in_a[2] = i_instr_req.data[23:16];
    data_in_a[3] = i_instr_req.data[31:24];
    if (i_instr_req.op == CBR_SW) we_a = 4'b1111;
end

// Data request -> Port B
// Handle byte level access
byte_access byte_access_b(
    .request(i_data_req),
    .data(data_in_b),
    .we(we_b)
);

bram_2_port #(.DEPTH(NUM_WORDS)) b0(
    .clk(clk), .resetn(resetn),
    .addr_a(addr_port_a), .addr_b(addr_port_b),
    .read_a(instr_read), .read_b(data_read),
    .data_in_b(data_in_b[0]), .we_b(we_b[0]), 
    .data_in_a(data_in_a[0]), .we_a(we_a[0]), 
    .data_a(o_instr_res.data[7:0]), .data_b(o_data_res.data[7:0])
);

bram_2_port #(.DEPTH(NUM_WORDS)) b1(
    .clk(clk), .resetn(resetn),
    .addr_a(addr_port_a), .addr_b(addr_port_b),
    .read_a(instr_read), .read_b(data_read),
    .data_in_b(data_in_b[1]), .we_b(we_b[1]), 
    .data_in_a(data_in_a[1]), .we_a(we_a[1]), 
    .data_a(o_instr_res.data[15:8]), .data_b(o_data_res.data[15:8])
);

bram_2_port #(.DEPTH(NUM_WORDS)) b2(
    .clk(clk), .resetn(resetn),
    .addr_a(addr_port_a), .addr_b(addr_port_b),
    .read_a(instr_read), .read_b(data_read),
    .data_in_b(data_in_b[2]), .we_b(we_b[2]), 
    .data_in_a(data_in_a[2]), .we_a(we_a[2]),
    .data_a(o_instr_res.data[23:16]), .data_b(o_data_res.data[23:16])
);

bram_2_port #(.DEPTH(NUM_WORDS)) b3(
    .clk(clk), .resetn(resetn),
    .addr_a(addr_port_a), .addr_b(addr_port_b),
    .read_a(instr_read), .read_b(data_read),
    .data_in_b(data_in_b[3]), .we_b(we_b[3]), 
    .data_in_a(data_in_a[3]), .we_a(we_a[3]), 
    .data_a(o_instr_res.data[31:24]), .data_b(o_data_res.data[31:24])
);

always_comb begin
    o_data_rdy = 1;
    o_instr_rdy = 1;
end

logic instr_done_reg, data_done_reg;

always_ff @(posedge clk) begin
    if (!resetn) begin
        instr_done_reg <= 0;
        data_done_reg <= 0;
    end

    else begin
        // Instr port
        if (i_instr_req.op != CBR_NOP && o_instr_rdy) begin
            instr_done_reg <= 1;
        end
        else begin
            instr_done_reg <= 0;
        end

        // Data port
        if (i_data_req.op != CBR_NOP && o_data_rdy) begin
            data_done_reg <= 1;
        end
        else begin
            data_done_reg <= 0;
        end
    end
end

always_comb begin 
    o_data_res.done = data_done_reg;
    o_instr_res.done = instr_done_reg;
end

endmodule
