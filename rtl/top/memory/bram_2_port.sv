// Generic Dual port BRAM 

module bram_2_port #(
    parameter int DEPTH = 32,
    parameter int WIDTH_BITS = 8,
    // Derived parameters
    parameter int NBITS_ADDR = $clog2(DEPTH)
) (
    input logic clk, resetn,
    input logic read_a, read_b,
    input logic [NBITS_ADDR - 1:0] addr_a, addr_b,
    input logic [WIDTH_BITS - 1:0] data_in_a, data_in_b,
    input logic we_a, we_b,
    output logic [WIDTH_BITS - 1:0] data_a, data_b
);

typedef logic [WIDTH_BITS - 1:0] _data_t;
_data_t ram [DEPTH] /* verilator public */;

always_ff @(posedge clk) begin
    // Reset only affects the registers
    if (!resetn) begin
        data_a <= 0;
    end else begin
        if (read_a) data_a <= ram[addr_a];
        if (we_a) ram[addr_a] <= data_in_a;
    end
end

always_ff @(posedge clk) begin
    // Reset only affects the registers
    if (!resetn) begin
        data_b <= 0;
    end else begin
        if (read_b) data_b <= ram[addr_b];
        if (we_b) ram[addr_b] <= data_in_b;
    end
end

endmodule
