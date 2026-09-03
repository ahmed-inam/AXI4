// Local write error responder. 2 instances (one per master port).
// Swallows the burst's W beats, then returns ONE BRESP=DECERR with AWID echoed.
// Takes no grant, but wr_port_ctrl still counts it and allocates a tracker entry.
module decerr_wr_resp
  import axi4_pkg::*;
(
  input  logic                aclk,
  input  logic                arst_n,

  input  logic                aw_accept,  // AW admitted with dest == DEST_DECERR
  input  logic [ID_WIDTH-1:0] aw_id,

  input  logic                w_beat,  // a W beat is being dropped this cycle
  input  logic                w_last,

  output logic                busy,  // blocks a second DECERR AW until this one's B has handshaked

  output logic                b_valid,
  output logic [ID_WIDTH-1:0] b_id,
  output logic [1:0]          b_resp,
  input  logic                b_ready
);

  typedef enum logic [1:0] {
    IDLE       = 2'd0,
    // AXI has no early burst termination: the master sends every beat regardless,
    // so DRAINING must accept all of them or the master hangs permanently.
    DRAINING   = 2'd1,
    RESPONDING = 2'd2
  } state_e;

  state_e state, next_state;

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) state <= IDLE;
    else         state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE:       if (aw_accept)        next_state = DRAINING;
      DRAINING:   if (w_beat && w_last) next_state = RESPONDING;
      RESPONDING: if (b_ready)          next_state = IDLE;
      default:                          next_state = IDLE;
    endcase
  end

  always_comb begin
    busy   = (state != IDLE);
    b_resp = RESP_DECERR;
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) b_valid <= 1'b0;
    else         b_valid <= (next_state == RESPONDING);
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n)        b_id <= '0;
    else if (aw_accept) b_id <= aw_id;
  end

  a_drain_only_when_owed: assert property (@(posedge aclk) disable iff (!arst_n)
    w_beat |-> (state == DRAINING))
    else $error("decerr_wr_resp: W beat dropped with no burst outstanding");

  a_one_at_a_time: assert property (@(posedge aclk) disable iff (!arst_n)
    aw_accept |-> !busy)
    else $error("decerr_wr_resp: second DECERR AW admitted while busy");

endmodule : decerr_wr_resp
