// Shared types, encodings and parameters for the AXI4 2x2 crossbar.
package axi4_pkg;
  localparam int NUM_MASTERS = 2;
  localparam int NUM_SLAVES  = 2;

  localparam int DATA_WIDTH = 32;
  localparam int ADDR_WIDTH = 32;
  localparam int ID_WIDTH   = 4;  // master-facing
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam int TAG_BITS   = $clog2(NUM_MASTERS);
  localparam int M_ID_W     = ID_WIDTH + TAG_BITS;  // slave-facing: +1 master tag bit

  localparam int MAX_OUTSTANDING = 4;  // per direction per port
  localparam int NUM_THREADS     = 2;  // distinct IDs; MUST be < MAX_OUTSTANDING

  // Guaranteed admissions per tenure. A bare !contested livelocks without this.
  localparam int TENURE_QUANTUM = 4;

  localparam int CNT_W    = $clog2(MAX_OUTSTANDING + 1);
  localparam int TENURE_W = $clog2(TENURE_QUANTUM  + 1);

  // Unsigned, correctly sized forms for comparison against counters.
  localparam logic [CNT_W-1:0]    MAX_OUT_Q  = CNT_W'(MAX_OUTSTANDING);
  localparam logic [TENURE_W-1:0] TENURE_Q   = TENURE_W'(TENURE_QUANTUM);

  // S0 = 0x0xxx_xxxx, S1 = 0x1xxx_xxxx, everything else DECERR. Upper-nibble compare.
  localparam int DEC_MSB = 31;
  localparam int DEC_LSB = 28;
  localparam int DEC_W   = DEC_MSB - DEC_LSB + 1;

  localparam logic [DEC_W-1:0] S0_PREFIX = 4'h0;
  localparam logic [DEC_W-1:0] S1_PREFIX = 4'h1;

  // Three targets, not two -- DECERR is a tracker dest value, which is what orders errors.
  typedef enum logic [1:0] {
    DEST_S0     = 2'd0,
    DEST_S1     = 2'd1,
    DEST_DECERR = 2'd2
  } dest_e;

  localparam int DEST_W = $bits(dest_e);

  // count != 0 means active. dest is required: the same ID to the SAME slave is legal.
  typedef struct packed {
    logic [ID_WIDTH-1:0] id;
    logic [CNT_W-1:0]    count;
    dest_e               dest;
  } thread_t;

  // Channel payloads as packed structs: the skid buffers stay generic (they take a
  // flat vector) but nothing has to slice bits by hand.
  typedef struct packed {
    logic [ID_WIDTH-1:0]   id;
    logic [ADDR_WIDTH-1:0] addr;
    logic [7:0]            len;
    logic [2:0]            size;
    logic [1:0]            burst;
  } axpay_t;   // AW and AR are identical

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic [STRB_WIDTH-1:0] strb;
    logic                  last;
  } wpay_t;

  typedef struct packed {
    logic [M_ID_W-1:0] id;
    logic [1:0]        resp;
  } bpay_t;

  typedef struct packed {
    logic [M_ID_W-1:0]     id;
    logic [DATA_WIDTH-1:0] data;
    logic [1:0]            resp;
    logic                  last;
  } rpay_t;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic [1:0]            resp;
  } rmux_t;

  typedef enum logic [1:0] {
    RESP_OKAY   = 2'b00,
    RESP_EXOKAY = 2'b01,  // never generated: exclusive access is out of scope
    RESP_SLVERR = 2'b10,
    RESP_DECERR = 2'b11
  } resp_e;

  typedef enum logic [1:0] {
    BURST_FIXED = 2'b00,
    BURST_INCR  = 2'b01,
    BURST_WRAP  = 2'b10  // 2'b11 is reserved and illegal while AxVALID is high
  } burst_e;

  // AXI4 extended only INCR to 256 beats (IHI0022E A3.4.1). For assertions and TB, not datapath.
  localparam logic [7:0] MAX_LEN_INCR  = 8'd255;
  localparam logic [7:0] MAX_LEN_FIXED = 8'd15;
  localparam logic [7:0] MAX_LEN_WRAP  = 8'd15;

  // Packages cannot hold procedural blocks -- these are asserted in axi4_xbar_top.sv.
  // The fabric is fixed 2x2: resp_return_mux has 3 hardcoded sources, port arrays are
  // [1:0], and the tag is sliced as a single bit. Widening must not elaborate silently.
  localparam bit CHK_TWO_MASTERS = (NUM_MASTERS == 2) && (NUM_SLAVES == 2);
  localparam bit CHK_ID_WIDTH = (M_ID_W >= ID_WIDTH + $clog2(NUM_MASTERS));
  localparam bit CHK_THREADS  = (NUM_THREADS < MAX_OUTSTANDING);
  localparam bit CHK_TENURE   = (TENURE_QUANTUM <= MAX_OUTSTANDING);
  localparam bit CHK_CNT_W    = ((1 << CNT_W)    > MAX_OUTSTANDING);
  localparam bit CHK_TENURE_W = ((1 << TENURE_W) > TENURE_QUANTUM);
  localparam bit CHK_DECODE   = (S0_PREFIX != S1_PREFIX);

  function automatic logic [M_ID_W-1:0]
      tag_id(input logic [ID_WIDTH-1:0] id, input int unsigned master_idx);
    return {master_idx[TAG_BITS-1:0], id};
  endfunction

endpackage : axi4_pkg
