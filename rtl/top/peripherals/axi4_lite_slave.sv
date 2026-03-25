`include "axi4_lite.svh"

module axi4_lite_slave
#(
    parameter int WDATA = 32,
    parameter int WADDR = 32,
    parameter int NREGS = 4,
    // Derived parameters
    parameter int WSTROBES = WDATA / 8,
    parameter int WSTROBES_BITS = $clog2(WSTROBES),
    parameter int NREGS_BITS = $clog2(NREGS)
)
(
    input logic i_clk, 
    input logic i_resetn,

    // AXI4-LITE-SL interface
    /* verilator lint_off UNUSEDSIGNAL */
    `AXI4_LITE_SLAVE_IO(intf)
    /* verilator lint_on UNUSEDSIGNAL */
);

logic [NREGS-1:0][WSTROBES-1:0][7:0] data_regs;

// Better View of data regs

/* verilator lint_off UNUSEDSIGNAL */
logic [NREGS-1:0][(8 * WSTROBES) - 1:0] view_data_regs;
/* verilator lint_on UNUSEDSIGNAL */

always_comb begin 
    for (int i = 0; i < NREGS; i += 1) begin 
        view_data_regs[i] = data_regs[i][WSTROBES-1:0];
    end
end


// Divide addr into strb and register id
logic [NREGS_BITS-1:0] awid, arid;
always_comb begin 
    awid = i_intf_axi_awaddr[NREGS_BITS-1+WSTROBES_BITS:WSTROBES_BITS];
    arid = i_intf_axi_araddr[NREGS_BITS-1+WSTROBES_BITS:WSTROBES_BITS];
end


// Write controller and registers
logic [NREGS_BITS-1:0] awid_reg;
logic [WSTROBES-1:0][7:0] wdata_reg;
logic [WSTROBES-1:0] strb_reg;

// Bypass data 
logic awready_byps, wdready_byps;
logic [NREGS_BITS-1:0] awid_byps;
logic [WSTROBES-1:0][7:0] wdata_byps;
logic [WSTROBES-1:0] strb_byps;

always_comb begin 
    awready_byps = o_intf_axi_awready;
    wdready_byps = o_intf_axi_wdready;
    awid_byps = awid_reg;
    wdata_byps = wdata_reg;
    strb_byps = strb_reg;

    if (i_intf_axi_wdvalid && o_intf_axi_wdready) begin 
        wdata_byps = i_intf_axi_wddata;
        strb_byps = i_intf_axi_wdstrb;
        wdready_byps = 0;
    end

    if (i_intf_axi_awvalid && o_intf_axi_awready) begin 
        awid_byps = awid;
        awready_byps = 0;
    end
end


// Write controller
always_ff @(posedge i_clk) begin

    // Reset or Write operation just finished
    if (!i_resetn || (o_intf_axi_bvalid && i_intf_axi_bready)) begin 
        // Setup ready for new operation
        o_intf_axi_bvalid <= 0; 
        o_intf_axi_wdready <= 1;
        o_intf_axi_awready <= 1;
    end

    // No Write request pending
    else if (!o_intf_axi_bvalid) begin 

        // Accept addr
        if (i_intf_axi_awvalid && o_intf_axi_awready) begin
            o_intf_axi_awready <= 0;
            awid_reg <= awid;
        end
        // Accept data
        if (i_intf_axi_wdvalid && o_intf_axi_wdready) begin 
            o_intf_axi_wdready <= 0;
            wdata_reg <= i_intf_axi_wddata;
            strb_reg <= i_intf_axi_wdstrb;
        end

        // No request pending and both addr and data accepted
        if (!awready_byps && !wdready_byps) begin

            // Write operation
            for (int i = 0; i < WSTROBES; i += 1) begin 
                if (strb_byps[i]) begin 
                    data_regs[awid_byps][i] <= wdata_byps[i];
                end
            end

            o_intf_axi_bvalid <= 1;
            o_intf_axi_bresp <= 0;
        end

    end
end


// Read controller
always_ff @(posedge i_clk) begin 

    // Reset or Read operation just finished
    if (!i_resetn || (o_intf_axi_rvalid && i_intf_axi_rready)) begin 
        o_intf_axi_arready <= 1;
        o_intf_axi_rvalid <= 0;
    end

    // New read operation accepted
    else if (!o_intf_axi_rvalid && o_intf_axi_arready && i_intf_axi_arvalid) begin
        o_intf_axi_arready <= 0;
        o_intf_axi_rvalid <= 1;
        o_intf_axi_rdata <= data_regs[arid];
        o_intf_axi_rresp <= 0;
    end

end

endmodule
