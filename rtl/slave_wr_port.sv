// Write side of one slave port. 2 instances.
// Round-robin between the two master ports, payload mux on the winner, and w_owner:
// W beats carry no address and no master id, so this end must remember whose beats
// it is forwarding.
module slave_wr_port
  import axi4_pkg::*;
(
  input  logic                  aclk,
  input  logic                  arst_n,

  input  logic [1:0]            m_awvalid,  // one bit per master port
  output logic [1:0]            m_awready,
  input  logic [1:0][M_ID_W-1:0]     m_awid,
  input  logic [1:0][ADDR_WIDTH-1:0] m_awaddr,
  input  logic [1:0][7:0]            m_awlen,
  input  logic [1:0][2:0]            m_awsize,
  input  logic [1:0][1:0]            m_awburst,

  input  logic [1:0]            m_wvalid,
  output logic [1:0]            m_wready,
  input  logic [1:0][DATA_WIDTH-1:0] m_wdata,
  input  logic [1:0][STRB_WIDTH-1:0] m_wstrb,
  input  logic [1:0]            m_wlast,

  input  logic [1:0]            arb_req,
  input  logic [1:0]            arb_ack,
  output logic [1:0]            arb_gnt,

  output logic                  s_awvalid,
  input  logic                  s_awready,
  output logic [M_ID_W-1:0]     s_awid,
  output logic [ADDR_WIDTH-1:0] s_awaddr,
  output logic [7:0]            s_awlen,
  output logic [2:0]            s_awsize,
  output logic [1:0]            s_awburst,

  output logic                  s_wvalid,
  input  logic                  s_wready,
  output logic [DATA_WIDTH-1:0] s_wdata,
  output logic [STRB_WIDTH-1:0] s_wstrb,
  output logic                  s_wlast
);

  logic gnt_valid;
  logic gnt_idx;  // 0 = M0, 1 = M1
  logic w_owner;

  // Writes hold the grant across a whole tenure with req low (arb_req is masked by
  // !mw_grant), so the idle-drop mode must NOT be used here.
  rr_arbiter #(.HOLD_IDLE_GRANT(1)) u_arb (
    .aclk      (aclk),
    .arst_n    (arst_n),
    .req       (arb_req),
    .ack       (arb_ack),
    .gnt       (arb_gnt),
    .gnt_valid (gnt_valid)
  );

  assign gnt_idx = arb_gnt[1];

  assign s_awvalid = gnt_valid && m_awvalid[gnt_idx];
  assign s_awid    = m_awid   [gnt_idx];
  assign s_awaddr  = m_awaddr [gnt_idx];
  assign s_awlen   = m_awlen  [gnt_idx];
  assign s_awsize  = m_awsize [gnt_idx];
  assign s_awburst = m_awburst[gnt_idx];

  assign m_awready[0] = gnt_valid && (gnt_idx == 1'b0) && s_awready;
  assign m_awready[1] = gnt_valid && (gnt_idx == 1'b1) && s_awready;

  // w_owner IS the arbiter's grant register -- no separate storage. The obvious
  // per-burst register cleared on WLAST wedges the port: this grant is per-TENURE,
  // so it would clear on burst 1's WLAST and never re-arm, because burst 2's AW
  // handshake happened cycles earlier. Deriving it also makes the two ends unable
  // to disagree.
  assign w_owner = gnt_idx;

  assign s_wvalid = gnt_valid && m_wvalid[w_owner];
  assign s_wdata  = m_wdata[w_owner];
  assign s_wstrb  = m_wstrb[w_owner];
  assign s_wlast  = m_wlast[w_owner];

  assign m_wready[0] = gnt_valid && (w_owner == 1'b0) && s_wready;
  assign m_wready[1] = gnt_valid && (w_owner == 1'b1) && s_wready;

  a_aw_one_master: assert property (@(posedge aclk) disable iff (!arst_n)
    $onehot0(m_awready))
    else $error("slave_wr_port: AW accepted from both masters");

  a_w_one_master: assert property (@(posedge aclk) disable iff (!arst_n)
    $onehot0(m_wready))
    else $error("slave_wr_port: W accepted from both masters -- bursts would interleave");

endmodule : slave_wr_port
