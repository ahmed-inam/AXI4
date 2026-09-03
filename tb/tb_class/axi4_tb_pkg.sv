`timescale 1ns/1ps

// Class-based testbench package. `include order is dependency order: a file may only
// reference things above it. Interfaces are not here -- they compile outside packages.

package axi4_tb_pkg;
  import axi4_pkg::*;

  // 0 verdicts only. 1 test banners and summaries. 2 adds a build trace (every
  // component announces itself at construction). 3 adds per-transaction monitor traffic.
  int tb_verbosity = 1;
  bit verbose = 0;

  `define TB_BUILD(CLS, NM) \
    if (tb_verbosity >= 2) \
      $display("[%0t] [BUILD] %-18s %-14s (%s:%0d)", $time, CLS, NM, `__FILE__, `__LINE__)

  int tb_mon_errors = 0;

  // When set, addresses with bit 26 high inside a real slave return SLVERR.
  // Deterministic, so the reference model can predict it (see axi4_txn::exp_resp).
  bit slverr_window = 0;

  localparam logic [31:0] S0_BASE  = 32'h0000_0000;
  localparam logic [31:0] S1_BASE  = 32'h1000_0000;
  localparam logic [31:0] BAD_BASE = 32'hF000_0000;

  typedef enum { WRITE, READ }                    dir_e;
  typedef enum { DEST_S0_T, DEST_S1_T, DEST_BAD } tdest_e;

  `include "axi4_txn.sv"

  `include "axi4_mst_driver.sv"
  `include "axi4_mst_monitor.sv"
  `include "axi4_slv_driver.sv"
  `include "axi4_slv_monitor.sv"

  `include "axi4_seq.sv"

  `include "axi4_ref_model.sv"
  `include "axi4_scoreboard.sv"

  `include "axi4_mst_agent.sv"
  `include "axi4_slv_agent.sv"

  `include "axi4_env.sv"

  `include "axi4_test.sv"

endpackage
