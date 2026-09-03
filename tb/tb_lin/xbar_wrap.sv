// elaboration wrapper.
// axi4_xbar_top has interface ports, so it cannot be an xelab top on its own.
// This instantiates the four interfaces and flattens them to plain signals, so
// xelab has a module with ordinary ports to elaborate and the binds in
// axi4_assert.sv have a concrete hierarchy to attach to.
//
// ID widths are explicit and MUST stay that way: axi4_if defaults ID_W to 4, so
// omitting the override on s0/s1 silently truncates the master tag bit and
// corrupts all response routing with no error anywhere.
module xbar_wrap
  import axi4_pkg::*;
(
  input  logic aclk,
  input  logic arst_n,

  input  logic [ID_WIDTH-1:0]   m0_awid,
  input  logic [ADDR_WIDTH-1:0] m0_awaddr,
  input  logic [7:0]            m0_awlen,
  input  logic [2:0]            m0_awsize,
  input  logic [1:0]            m0_awburst,
  input  logic                  m0_awvalid,
  output logic                  m0_awready,
  input  logic [DATA_WIDTH-1:0] m0_wdata,
  input  logic [STRB_WIDTH-1:0] m0_wstrb,
  input  logic                  m0_wlast,
  input  logic                  m0_wvalid,
  output logic                  m0_wready,
  output logic [ID_WIDTH-1:0]   m0_bid,
  output logic [1:0]            m0_bresp,
  output logic                  m0_bvalid,
  input  logic                  m0_bready,
  input  logic [ID_WIDTH-1:0]   m0_arid,
  input  logic [ADDR_WIDTH-1:0] m0_araddr,
  input  logic [7:0]            m0_arlen,
  input  logic [2:0]            m0_arsize,
  input  logic [1:0]            m0_arburst,
  input  logic                  m0_arvalid,
  output logic                  m0_arready,
  output logic [ID_WIDTH-1:0]   m0_rid,
  output logic [DATA_WIDTH-1:0] m0_rdata,
  output logic [1:0]            m0_rresp,
  output logic                  m0_rlast,
  output logic                  m0_rvalid,
  input  logic                  m0_rready,

  input  logic [ID_WIDTH-1:0]   m1_awid,
  input  logic [ADDR_WIDTH-1:0] m1_awaddr,
  input  logic [7:0]            m1_awlen,
  input  logic [2:0]            m1_awsize,
  input  logic [1:0]            m1_awburst,
  input  logic                  m1_awvalid,
  output logic                  m1_awready,
  input  logic [DATA_WIDTH-1:0] m1_wdata,
  input  logic [STRB_WIDTH-1:0] m1_wstrb,
  input  logic                  m1_wlast,
  input  logic                  m1_wvalid,
  output logic                  m1_wready,
  output logic [ID_WIDTH-1:0]   m1_bid,
  output logic [1:0]            m1_bresp,
  output logic                  m1_bvalid,
  input  logic                  m1_bready,
  input  logic [ID_WIDTH-1:0]   m1_arid,
  input  logic [ADDR_WIDTH-1:0] m1_araddr,
  input  logic [7:0]            m1_arlen,
  input  logic [2:0]            m1_arsize,
  input  logic [1:0]            m1_arburst,
  input  logic                  m1_arvalid,
  output logic                  m1_arready,
  output logic [ID_WIDTH-1:0]   m1_rid,
  output logic [DATA_WIDTH-1:0] m1_rdata,
  output logic [1:0]            m1_rresp,
  output logic                  m1_rlast,
  output logic                  m1_rvalid,
  input  logic                  m1_rready,

  output logic [M_ID_W-1:0]     s0_awid,
  output logic [ADDR_WIDTH-1:0] s0_awaddr,
  output logic [7:0]            s0_awlen,
  output logic [2:0]            s0_awsize,
  output logic [1:0]            s0_awburst,
  output logic                  s0_awvalid,
  input  logic                  s0_awready,
  output logic [DATA_WIDTH-1:0] s0_wdata,
  output logic [STRB_WIDTH-1:0] s0_wstrb,
  output logic                  s0_wlast,
  output logic                  s0_wvalid,
  input  logic                  s0_wready,
  input  logic [M_ID_W-1:0]     s0_bid,
  input  logic [1:0]            s0_bresp,
  input  logic                  s0_bvalid,
  output logic                  s0_bready,
  output logic [M_ID_W-1:0]     s0_arid,
  output logic [ADDR_WIDTH-1:0] s0_araddr,
  output logic [7:0]            s0_arlen,
  output logic [2:0]            s0_arsize,
  output logic [1:0]            s0_arburst,
  output logic                  s0_arvalid,
  input  logic                  s0_arready,
  input  logic [M_ID_W-1:0]     s0_rid,
  input  logic [DATA_WIDTH-1:0] s0_rdata,
  input  logic [1:0]            s0_rresp,
  input  logic                  s0_rlast,
  input  logic                  s0_rvalid,
  output logic                  s0_rready,

  output logic [M_ID_W-1:0]     s1_awid,
  output logic [ADDR_WIDTH-1:0] s1_awaddr,
  output logic [7:0]            s1_awlen,
  output logic [2:0]            s1_awsize,
  output logic [1:0]            s1_awburst,
  output logic                  s1_awvalid,
  input  logic                  s1_awready,
  output logic [DATA_WIDTH-1:0] s1_wdata,
  output logic [STRB_WIDTH-1:0] s1_wstrb,
  output logic                  s1_wlast,
  output logic                  s1_wvalid,
  input  logic                  s1_wready,
  input  logic [M_ID_W-1:0]     s1_bid,
  input  logic [1:0]            s1_bresp,
  input  logic                  s1_bvalid,
  output logic                  s1_bready,
  output logic [M_ID_W-1:0]     s1_arid,
  output logic [ADDR_WIDTH-1:0] s1_araddr,
  output logic [7:0]            s1_arlen,
  output logic [2:0]            s1_arsize,
  output logic [1:0]            s1_arburst,
  output logic                  s1_arvalid,
  input  logic                  s1_arready,
  input  logic [M_ID_W-1:0]     s1_rid,
  input  logic [DATA_WIDTH-1:0] s1_rdata,
  input  logic [1:0]            s1_rresp,
  input  logic                  s1_rlast,
  input  logic                  s1_rvalid,
  output logic                  s1_rready
);

  axi4_if #(.ID_W(ID_WIDTH)) m0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(ID_WIDTH)) m1 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s1 (.aclk(aclk), .arst_n(arst_n));

  axi4_xbar_top dut (
    .aclk(aclk), .arst_n(arst_n),
    .m0(m0), .m1(m1), .s0(s0), .s1(s1));

  assign m0.awid = m0_awid; assign m0.awaddr = m0_awaddr; assign m0.awlen = m0_awlen;
  assign m0.awsize = m0_awsize; assign m0.awburst = m0_awburst; assign m0.awvalid = m0_awvalid;
  assign m0_awready = m0.awready;
  assign m0.wdata = m0_wdata; assign m0.wstrb = m0_wstrb; assign m0.wlast = m0_wlast;
  assign m0.wvalid = m0_wvalid; assign m0_wready = m0.wready;
  assign m0_bid = m0.bid; assign m0_bresp = m0.bresp; assign m0_bvalid = m0.bvalid;
  assign m0.bready = m0_bready;
  assign m0.arid = m0_arid; assign m0.araddr = m0_araddr; assign m0.arlen = m0_arlen;
  assign m0.arsize = m0_arsize; assign m0.arburst = m0_arburst; assign m0.arvalid = m0_arvalid;
  assign m0_arready = m0.arready;
  assign m0_rid = m0.rid; assign m0_rdata = m0.rdata; assign m0_rresp = m0.rresp;
  assign m0_rlast = m0.rlast; assign m0_rvalid = m0.rvalid; assign m0.rready = m0_rready;

  assign m1.awid = m1_awid; assign m1.awaddr = m1_awaddr; assign m1.awlen = m1_awlen;
  assign m1.awsize = m1_awsize; assign m1.awburst = m1_awburst; assign m1.awvalid = m1_awvalid;
  assign m1_awready = m1.awready;
  assign m1.wdata = m1_wdata; assign m1.wstrb = m1_wstrb; assign m1.wlast = m1_wlast;
  assign m1.wvalid = m1_wvalid; assign m1_wready = m1.wready;
  assign m1_bid = m1.bid; assign m1_bresp = m1.bresp; assign m1_bvalid = m1.bvalid;
  assign m1.bready = m1_bready;
  assign m1.arid = m1_arid; assign m1.araddr = m1_araddr; assign m1.arlen = m1_arlen;
  assign m1.arsize = m1_arsize; assign m1.arburst = m1_arburst; assign m1.arvalid = m1_arvalid;
  assign m1_arready = m1.arready;
  assign m1_rid = m1.rid; assign m1_rdata = m1.rdata; assign m1_rresp = m1.rresp;
  assign m1_rlast = m1.rlast; assign m1_rvalid = m1.rvalid; assign m1.rready = m1_rready;

  assign s0_awid = s0.awid; assign s0_awaddr = s0.awaddr; assign s0_awlen = s0.awlen;
  assign s0_awsize = s0.awsize; assign s0_awburst = s0.awburst; assign s0_awvalid = s0.awvalid;
  assign s0.awready = s0_awready;
  assign s0_wdata = s0.wdata; assign s0_wstrb = s0.wstrb; assign s0_wlast = s0.wlast;
  assign s0_wvalid = s0.wvalid; assign s0.wready = s0_wready;
  assign s0.bid = s0_bid; assign s0.bresp = s0_bresp; assign s0.bvalid = s0_bvalid;
  assign s0_bready = s0.bready;
  assign s0_arid = s0.arid; assign s0_araddr = s0.araddr; assign s0_arlen = s0.arlen;
  assign s0_arsize = s0.arsize; assign s0_arburst = s0.arburst; assign s0_arvalid = s0.arvalid;
  assign s0.arready = s0_arready;
  assign s0.rid = s0_rid; assign s0.rdata = s0_rdata; assign s0.rresp = s0_rresp;
  assign s0.rlast = s0_rlast; assign s0.rvalid = s0_rvalid; assign s0_rready = s0.rready;

  assign s1_awid = s1.awid; assign s1_awaddr = s1.awaddr; assign s1_awlen = s1.awlen;
  assign s1_awsize = s1.awsize; assign s1_awburst = s1.awburst; assign s1_awvalid = s1.awvalid;
  assign s1.awready = s1_awready;
  assign s1_wdata = s1.wdata; assign s1_wstrb = s1.wstrb; assign s1_wlast = s1.wlast;
  assign s1_wvalid = s1.wvalid; assign s1.wready = s1_wready;
  assign s1.bid = s1_bid; assign s1.bresp = s1_bresp; assign s1.bvalid = s1_bvalid;
  assign s1_bready = s1.bready;
  assign s1_arid = s1.arid; assign s1_araddr = s1.araddr; assign s1_arlen = s1.arlen;
  assign s1_arsize = s1.arsize; assign s1_arburst = s1.arburst; assign s1_arvalid = s1.arvalid;
  assign s1.arready = s1_arready;
  assign s1.rid = s1_rid; assign s1.rdata = s1_rdata; assign s1.rresp = s1_rresp;
  assign s1.rlast = s1_rlast; assign s1.rvalid = s1_rvalid; assign s1_rready = s1.rready;

endmodule : xbar_wrap
