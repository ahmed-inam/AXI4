// 2-register skid buffer with registered outputs. 10 instances.
// s_* is upstream (into the buffer), m_* is downstream (out of it).
module skid_buffer #(
  parameter int W = 8
) (
  input  logic         aclk,
  input  logic         arst_n,

  input  logic         s_valid,
  output logic         s_ready,
  input  logic [W-1:0] s_data,

  output logic         m_valid,
  input  logic         m_ready,
  output logic [W-1:0] m_data
);

  typedef enum logic [1:0] {
    EMPTY = 2'd0,
    ONE   = 2'd1,
    FULL  = 2'd2
  } skid_state_e;

  skid_state_e  state, next_state;
  logic [W-1:0] temp_data;

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) state <= EMPTY;
    else         state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      EMPTY:   if (s_valid)                  next_state = ONE;
      ONE:     if (s_valid && !m_ready)      next_state = FULL;  // arrival with the output stalled -- the skid
               else if (!s_valid && m_ready) next_state = EMPTY;
      FULL:    if (m_ready)                  next_state = ONE;
      default:                               next_state = FULL;  // illegal encoding: drain out, never drop
    endcase
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) m_valid <= 1'b0;
    // Registered off next_state, not decoded from state: this feeds the deepest
    // path in the design and a decode adds a gate at the head of it.
    else         m_valid <= (next_state != EMPTY);
  end

  // && arst_n: without it READY reads 1 while held in reset, and since srst_n lags
  // raw arst_n a master would handshake into a dropped transfer.
  assign s_ready = (state != FULL) && arst_n;

  always_ff @(posedge aclk) begin
    case (state)
      EMPTY:   if (s_valid) m_data <= s_data;
      ONE:     if (s_valid) begin
                 if (m_ready) m_data    <= s_data;
                 else         temp_data <= s_data;
               end
      FULL:    if (m_ready) m_data <= temp_data;
      default: ;
    endcase
  end

endmodule : skid_buffer
