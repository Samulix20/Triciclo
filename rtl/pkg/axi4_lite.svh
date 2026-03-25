
/*

Macros to help connect and declare all AXI4 lite signals

*/

`define AXI4_LITE_MASTER_IO(name) \
    output logic o_``name``_axi_awvalid, \
    input logic i_``name``_axi_awready, \
    output logic [WADDR-1:0] o_``name``_axi_awaddr, \
    output logic [2:0] o_``name``_axi_awwprot, \
    output logic [3:0] o_``name``_axi_awcache, \
    output logic o_``name``_axi_wdvalid, \
    input logic i_``name``_axi_wdready, \
    output logic [WDATA-1:0] o_``name``_axi_wddata, \
    output logic [WSTROBES-1:0] o_``name``_axi_wdstrb, \
    input logic i_``name``_axi_bvalid, \
    output logic o_``name``_axi_bready, \
    input logic [1:0] i_``name``_axi_bresp,  \
    output logic o_``name``_axi_arvalid, \
    input logic i_``name``_axi_arready, \
    output logic [WDATA-1:0] o_``name``_axi_araddr, \
    output logic [2:0] o_``name``_axi_arwprot, \
    output logic [3:0] o_``name``_axi_arcache, \
    input logic i_``name``_axi_rvalid, \
    output logic o_``name``_axi_rready, \
    input logic [WDATA-1:0] i_``name``_axi_rdata, \
    input logic [1:0] i_``name``_axi_rresp


`define AXI4_LITE_SLAVE_IO(name) \
    input logic i_``name``_axi_awvalid, \
    output logic o_``name``_axi_awready, \
    input logic [WADDR-1:0] i_``name``_axi_awaddr, \
    input logic [2:0] i_``name``_axi_awwprot, \
    input logic [3:0] i_``name``_axi_awcache, \
    input logic i_``name``_axi_wdvalid, \
    output logic o_``name``_axi_wdready, \
    input logic [WDATA-1:0] i_``name``_axi_wddata, \
    input logic [WSTROBES-1:0] i_``name``_axi_wdstrb, \
    output logic o_``name``_axi_bvalid, \
    input logic i_``name``_axi_bready, \
    output logic [1:0] o_``name``_axi_bresp, \
    input logic i_``name``_axi_arvalid, \
    output logic o_``name``_axi_arready, \
    input logic [WDATA-1:0] i_``name``_axi_araddr, \
    input logic [2:0] i_``name``_axi_arwprot, \
    input logic [3:0] i_``name``_axi_arcache, \
    output logic o_``name``_axi_rvalid, \
    input logic i_``name``_axi_rready, \
    output logic [WDATA-1:0] o_``name``_axi_rdata, \
    output logic [1:0] o_``name``_axi_rresp


`define AXI4_LITE_BUS(name, waddr, wdata, wstrobes) \
    logic name``_axi_awvalid; \
    logic name``_axi_awready; \
    logic [waddr-1:0] name``_axi_awaddr; \
    logic [2:0] name``_axi_awwprot; \
    logic [3:0] name``_axi_awcache; \
    logic name``_axi_wdvalid; \
    logic name``_axi_wdready; \
    logic [wdata-1:0] name``_axi_wddata; \
    logic [wstrobes-1:0] name``_axi_wdstrb; \
    logic name``_axi_bvalid; \
    logic name``_axi_bready; \
    logic [1:0] name``_axi_bresp; \
    logic name``_axi_arvalid; \
    logic name``_axi_arready; \
    logic [wdata-1:0] name``_axi_araddr; \
    logic [2:0] name``_axi_arwprot; \
    logic [3:0] name``_axi_arcache; \
    logic name``_axi_rvalid; \
    logic name``_axi_rready; \
    logic [wdata-1:0] name``_axi_rdata; \
    logic [1:0] name``_axi_rresp


`define AXI4_LITE_MASTER_CONNECT(bname, iname) \
    .o_``iname``_axi_awvalid(bname``_axi_awvalid), \
    .i_``iname``_axi_awready(bname``_axi_awready), \
    .o_``iname``_axi_awaddr(bname``_axi_awaddr), \
    .o_``iname``_axi_awwprot(bname``_axi_awwprot), \
    .o_``iname``_axi_awcache(bname``_axi_awcache), \
    .o_``iname``_axi_wdvalid(bname``_axi_wdvalid), \
    .i_``iname``_axi_wdready(bname``_axi_wdready), \
    .o_``iname``_axi_wddata(bname``_axi_wddata), \
    .o_``iname``_axi_wdstrb(bname``_axi_wdstrb), \
    .i_``iname``_axi_bvalid(bname``_axi_bvalid), \
    .o_``iname``_axi_bready(bname``_axi_bready), \
    .i_``iname``_axi_bresp(bname``_axi_bresp), \
    .o_``iname``_axi_arvalid(bname``_axi_arvalid), \
    .i_``iname``_axi_arready(bname``_axi_arready), \
    .o_``iname``_axi_araddr(bname``_axi_araddr), \
    .o_``iname``_axi_arwprot(bname``_axi_arwprot), \
    .o_``iname``_axi_arcache(bname``_axi_arcache), \
    .i_``iname``_axi_rvalid(bname``_axi_rvalid), \
    .o_``iname``_axi_rready(bname``_axi_rready), \
    .i_``iname``_axi_rdata(bname``_axi_rdata), \
    .i_``iname``_axi_rresp(bname``_axi_rresp)


`define AXI4_LITE_SLAVE_CONNECT(bname, iname) \
    .i_``iname``_axi_awvalid(bname``_axi_awvalid), \
    .o_``iname``_axi_awready(bname``_axi_awready), \
    .i_``iname``_axi_awaddr(bname``_axi_awaddr), \
    .i_``iname``_axi_awwprot(bname``_axi_awwprot), \
    .i_``iname``_axi_awcache(bname``_axi_awcache), \
    .i_``iname``_axi_wdvalid(bname``_axi_wdvalid), \
    .o_``iname``_axi_wdready(bname``_axi_wdready), \
    .i_``iname``_axi_wddata(bname``_axi_wddata), \
    .i_``iname``_axi_wdstrb(bname``_axi_wdstrb), \
    .o_``iname``_axi_bvalid(bname``_axi_bvalid), \
    .i_``iname``_axi_bready(bname``_axi_bready), \
    .o_``iname``_axi_bresp(bname``_axi_bresp), \
    .i_``iname``_axi_arvalid(bname``_axi_arvalid), \
    .o_``iname``_axi_arready(bname``_axi_arready), \
    .i_``iname``_axi_araddr(bname``_axi_araddr), \
    .i_``iname``_axi_arwprot(bname``_axi_arwprot), \
    .i_``iname``_axi_arcache(bname``_axi_arcache), \
    .o_``iname``_axi_rvalid(bname``_axi_rvalid), \
    .i_``iname``_axi_rready(bname``_axi_rready), \
    .o_``iname``_axi_rdata(bname``_axi_rdata), \
    .o_``iname``_axi_rresp(bname``_axi_rresp)
