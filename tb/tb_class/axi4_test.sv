// Base test and the scenario library. The base owns the env, starts it, runs body(),
// drains and reports; each test overrides body() only.
//
// Whitebox signals arrive through a probe interface: a package cannot reference a
// module hierarchy, so tb_top samples them structurally and passes the handle in.
class axi4_test;

  virtual axi4_if #(.ID_W(ID_WIDTH)) m0_vif, m1_vif;
  virtual axi4_if #(.ID_W(M_ID_W))   s0_vif, s1_vif;
  virtual xbar_probe_if              pb;

  axi4_env env;
  string   name = "TEST";
  int      n_local_fail = 0;
  bit      done = 0;

  function new(virtual axi4_if #(.ID_W(ID_WIDTH)) m0,
               virtual axi4_if #(.ID_W(ID_WIDTH)) m1,
               virtual axi4_if #(.ID_W(M_ID_W))   s0,
               virtual axi4_if #(.ID_W(M_ID_W))   s1,
               virtual xbar_probe_if              pb);
    m0_vif = m0;  m1_vif = m1;  s0_vif = s0;  s1_vif = s1;
    this.pb = pb;
  endfunction

  task pulse_reset(int cycles = 5);
    pb.rst_req = cycles;
    wait (pb.rst_req == 0);
  endtask

  virtual task body();
  endtask

  task run();
    env = new(m0_vif, m1_vif, s0_vif, s1_vif);
    env.build();
    env.run();

    wait (m0_vif.arst_n === 1'b1);
    repeat (5) @(posedge m0_vif.aclk);

    $display("\n[%0t] [%s] starting", $time, name);
    body();

    drain();
    $display("[%0t] [%s] finished", $time, name);
    env.report();
    if (n_local_fail != 0)
      $display("[%s] %0d LOCAL CHECK FAILURE(S)", name, n_local_fail);
    begin
      bit ok = (env.scb.n_errors == 0) && (env.scb.outstanding() == 0)
               && (n_local_fail == 0) && (tb_mon_errors == 0);
      $display("[%s] FINAL VERDICT: %s (scb=%0d outstanding=%0d local=%0d mon=%0d)",
               name, ok ? "PASS" : "FAIL",
               env.scb.n_errors, env.scb.outstanding(), n_local_fail, tb_mon_errors);
    end
    done = 1;
  endtask

  task drain(int limit = 40000);
    for (int i = 0; i < limit; i++) begin
      @(posedge m0_vif.aclk);
      if (env.scb.n_issued > 0 && env.idle()) begin
        repeat (20) @(posedge m0_vif.aclk);
        if (env.idle()) return;
      end
    end
    $display("[%0t] [%s] DRAIN TIMEOUT: %0d still outstanding",
             $time, name, env.scb.outstanding());
    n_local_fail++;
  endtask

  task tick(int n = 1); repeat (n) @(posedge m0_vif.aclk); endtask

  function void chk(string tag, bit cond, string msg = "");
    if (cond) $display("  %s PASS", tag);
    else begin
      $display("  %s FAIL: %s", tag, msg);
      n_local_fail++;
    end
  endfunction

  function axi4_seq new_seq(int m);
    new_seq = new(env.m_agt[m].seq_out_mbx);
    env.m_agt[m].seq = new_seq;
  endfunction

endclass

`define TEST_CTOR(NM)                                                 \
  function new(virtual axi4_if #(.ID_W(ID_WIDTH)) m0,                 \
               virtual axi4_if #(.ID_W(ID_WIDTH)) m1,                 \
               virtual axi4_if #(.ID_W(M_ID_W))   s0,                 \
               virtual axi4_if #(.ID_W(M_ID_W))   s1,                 \
               virtual xbar_probe_if              pb);                \
    super.new(m0, m1, s0, s1, pb);                                    \
    name = NM;                                                        \
    `TB_BUILD("test", name);                                          \
  endfunction

// ---- basic ----
class axi4_test_smoke extends axi4_test;
  `TEST_CTOR("SMOKE")
  virtual task body();
    axi4_seq s = new_seq(0);
    s.push(WRITE, 4'd3, S0_BASE + 32'h100, 8'd3);
    s.run();
    drain();
    s = new_seq(0);
    s.push(READ, 4'd3, S0_BASE + 32'h100, 8'd3);
    s.run();
  endtask
endclass

// Both masters to one slave, responses released together -- the interleaving the
// response-mux READY leak needs.
class axi4_test_cross extends axi4_test;
  `TEST_CTOR("CROSS")
  virtual task body();
    env.s_agt[0].drv.dam = 1;
    fork
      begin axi4_seq a = new_seq(0); a.push(WRITE, 4'd5, S0_BASE + 32'h200, 8'd1); a.run(); end
      begin axi4_seq b = new_seq(1); b.push(WRITE, 4'd9, S0_BASE + 32'h300, 8'd1); b.run(); end
    join
    tick(60);
    env.s_agt[0].drv.dam = 0;
  endtask
endclass

class axi4_test_cross_rd extends axi4_test;
  `TEST_CTOR("CROSS_RD")
  virtual task body();
    axi4_seq w = new_seq(0);
    w.push(WRITE, 4'd1, S0_BASE + 32'h400, 8'd3);
    w.push(WRITE, 4'd1, S0_BASE + 32'h500, 8'd3);
    w.run();
    drain();

    env.s_agt[0].drv.dam = 1;
    fork
      begin axi4_seq a = new_seq(0); a.push(READ, 4'd6, S0_BASE + 32'h400, 8'd3); a.run(); end
      begin axi4_seq b = new_seq(1); b.push(READ, 4'd8, S0_BASE + 32'h500, 8'd3); b.run(); end
    join
    tick(60);
    env.s_agt[0].drv.dam = 0;
  endtask
endclass

class axi4_test_decerr extends axi4_test;
  `TEST_CTOR("DECERR")
  virtual task body();
    axi4_seq s = new_seq(0);
    s.push(WRITE, 4'd5, BAD_BASE,          8'd3);
    s.push(READ,  4'd6, BAD_BASE + 32'h40, 8'd3);
    s.run();
  endtask
endclass

// ---- grant lifecycle ----
// Acquisition is gated on !mw_full: at the outstanding limit the port must not
// request a different slave.
class axi4_test_t9 extends axi4_test;
  `TEST_CTOR("T9_DESTSWITCH")
  virtual task body();
    bit req_while_full = 0;
    axi4_seq s;

    env.s_agt[0].drv.dam = 1;
    s = new_seq(0);
    s.push_burst_stream(WRITE, 4'd1, S0_BASE + 32'h100, MAX_OUTSTANDING, 8'd1);
    s.run();
    tick(80);
    chk("T9a", (pb.p0_aw_pending == MAX_OUTSTANDING),
        $sformatf("aw_pending=%0d", pb.p0_aw_pending));

    fork
      begin axi4_seq d = new_seq(0); d.push(WRITE, 4'd2, S1_BASE, 8'd1); d.run(); end
      begin
        for (int i = 0; i < 40; i++) begin
          tick();
          if (pb.p0_arb_req != 2'b00 && pb.p0_mw_full) req_while_full = 1;
        end
        chk("T9b", !req_while_full, "arbiter requested while at the limit");
        env.s_agt[0].drv.dam = 0;
      end
    join
  endtask
endclass

// Uncontested, the grant must be retained after data drains.
class axi4_test_t10 extends axi4_test;
  `TEST_CTOR("T10_RETAIN")
  virtual task body();
    axi4_seq s = new_seq(0);
    s.push(WRITE, 4'd3, S0_BASE, 8'd1);
    s.run();
    drain();
    tick(3);
    chk("T10", (pb.p0_mw_grant === 1'b1 && pb.p0_mw_dest === DEST_S0),
        $sformatf("grant=%b dest=%0d", pb.p0_mw_grant, pb.p0_mw_dest));
  endtask
endclass

class axi4_test_t11 extends axi4_test;
  `TEST_CTOR("T11_NEEDSDIFF")
  virtual task body();
    bit saw_release = 0;
    axi4_seq s = new_seq(0);
    s.push(WRITE, 4'd4, S0_BASE, 8'd1);
    s.run();
    drain();

    fork
      begin axi4_seq d = new_seq(0); d.push(WRITE, 4'd4, S1_BASE, 8'd1); d.run(); end
      begin
        for (int i = 0; i < 400; i++) begin
          tick();
          if (pb.p0_mw_release) saw_release = 1;
        end
      end
    join
    chk("T11", saw_release, "mw_release never fired on a destination change");
  endtask
endclass

// Contention forces handover and the tenure quantum is reached. Pipelined issue is
// essential: serialised bursts drop w_pending to zero between them and tenure_cnt
// never climbs past 2.
class axi4_test_t13 extends axi4_test;
  `TEST_CTOR("T13_TENURE")
  virtual task body();
    int max_ten = 0;
    bit handover = 0;
    logic prev_gnt;

    fork
      begin
        axi4_seq a = new_seq(0);
        a.push_burst_stream(WRITE, 4'd5, S0_BASE + 32'h000, 12, 8'd1);
        a.run();
      end
      begin
        axi4_seq b = new_seq(1);
        b.push_burst_stream(WRITE, 4'd6, S0_BASE + 32'h400, 12, 8'd1);
        b.run();
      end
      begin
        prev_gnt = pb.s0w_arb_gnt[0];
        for (int i = 0; i < 8000; i++) begin
          tick();
          if (pb.p0_tenure_cnt > max_ten) max_ten = pb.p0_tenure_cnt;
          if (pb.s0w_arb_gnt[0] !== prev_gnt) handover = 1;
          prev_gnt = pb.s0w_arb_gnt[0];
        end
      end
    join_any
    drain();
    chk("T13a", handover, "grant never handed over");
    chk("T13b", (max_ten >= TENURE_QUANTUM),
        $sformatf("tenure_cnt peaked at %0d, expected %0d", max_ten, TENURE_QUANTUM));
  endtask
endclass

class axi4_test_t14 extends axi4_test;
  `TEST_CTOR("T14_DECERR_LOCK")
  virtual task body();
    bit bad_admit = 0;
    axi4_seq s = new_seq(0);
    s.push(WRITE, 4'd7, S0_BASE, 8'd1);
    s.run();
    drain();
    tick(3);

    fork
      begin axi4_seq d = new_seq(0); d.push(WRITE, 4'd8, BAD_BASE, 8'd1); d.run(); end
      begin
        for (int i = 0; i < 400; i++) begin
          tick();
          if (pb.p0_aw_admit && (pb.p0_aw_dest === DEST_DECERR) && pb.p0_mw_grant)
            bad_admit = 1;
        end
      end
    join
    chk("T14", !bad_admit, "DECERR admitted while a grant was held");
  endtask
endclass

class axi4_test_t15 extends axi4_test;
  `TEST_CTOR("T15_MWFULL")
  virtual task body();
    bit admitted_while_full = 0;
    axi4_seq s;

    env.s_agt[0].drv.dam = 1;
    s = new_seq(0);
    s.push_burst_stream(WRITE, 4'd9, S0_BASE, MAX_OUTSTANDING, 8'd1);
    s.run();
    tick(80);
    chk("T15a", (pb.p0_aw_pending == MAX_OUTSTANDING && pb.p0_mw_full),
        $sformatf("aw_pending=%0d mw_full=%b", pb.p0_aw_pending, pb.p0_mw_full));

    fork
      begin axi4_seq d = new_seq(0); d.push(WRITE, 4'd9, S0_BASE + 32'h400, 8'd1); d.run(); end
      begin
        for (int i = 0; i < 40; i++) begin
          tick();
          if (pb.p0_aw_admit && pb.p0_mw_full) admitted_while_full = 1;
        end
        chk("T15b", !admitted_while_full, "admitted while at the limit");
        env.s_agt[0].drv.dam = 0;
      end
    join
  endtask
endclass

// NUM_THREADS = 2, so a third distinct ID blocks on thread allocation while still
// well clear of the outstanding limit.
class axi4_test_t16 extends axi4_test;
  `TEST_CTOR("T16_THRFULL")
  virtual task body();
    bit blocked_on_thr = 0;
    axi4_seq s;

    env.s_agt[0].drv.dam = 1;
    s = new_seq(0);
    s.push(WRITE, 4'd1, S0_BASE + 32'h000, 8'd1);
    s.push(WRITE, 4'd2, S0_BASE + 32'h040, 8'd1);
    s.run();
    tick(80);
    chk("T16a", (pb.p0_aw_pending == 2 && !pb.p0_mw_full),
        $sformatf("aw_pending=%0d mw_full=%b", pb.p0_aw_pending, pb.p0_mw_full));

    fork
      begin axi4_seq d = new_seq(0); d.push(WRITE, 4'd3, S0_BASE + 32'h080, 8'd1); d.run(); end
      begin
        for (int i = 0; i < 40; i++) begin
          tick();
          if (!pb.p0_thr_ok && !pb.p0_mw_full) blocked_on_thr = 1;
        end
        chk("T16b", blocked_on_thr, "third distinct ID was not blocked");
        env.s_agt[0].drv.dam = 0;
      end
    join
  endtask
endclass

// Same ID same destination pipelines; same ID to a different destination blocks.
class axi4_test_t17 extends axi4_test;
  `TEST_CTOR("T17_ORDERING")
  virtual task body();
    bit blocked = 0;
    axi4_seq s;

    env.s_agt[0].drv.dam = 1;
    s = new_seq(0);
    s.push(WRITE, 4'd4, S0_BASE + 32'h000, 8'd1);
    s.push(WRITE, 4'd4, S0_BASE + 32'h040, 8'd1);
    s.run();
    tick(80);
    chk("T17a", (pb.p0_aw_pending == 2),
        $sformatf("same ID same dest did not pipeline: aw_pending=%0d", pb.p0_aw_pending));

    fork
      begin axi4_seq d = new_seq(0); d.push(WRITE, 4'd4, S1_BASE, 8'd1); d.run(); end
      begin
        for (int i = 0; i < 40; i++) begin
          tick();
          if (!pb.p0_thr_ok) blocked = 1;
        end
        chk("T17b", blocked, "same ID to a different slave was not blocked");
        env.s_agt[0].drv.dam = 0;
      end
    join
  endtask
endclass

// ---- response path ----
class axi4_test_t7 extends axi4_test;
  `TEST_CTOR("T7_BOTHSLAVES")
  virtual task body();
    axi4_seq s = new_seq(0);
    s.push(WRITE, 4'd1, S0_BASE + 32'h800, 8'd3);
    s.push(WRITE, 4'd2, S1_BASE + 32'h800, 8'd3);
    s.run();
    drain();

    s = new_seq(0);
    s.push(READ, 4'd3, S0_BASE + 32'h800, 8'd3);
    s.push(READ, 4'd4, S1_BASE + 32'h800, 8'd3);
    s.run();
  endtask
endclass

// ---- reset: the tests env.flush() exists for ----
class axi4_test_t20 extends axi4_test;
  `TEST_CTOR("T20_RST_MIDBURST")
  virtual task body();
    axi4_seq s = new_seq(0);
    s.push_burst_stream(WRITE, 4'd2, S0_BASE, 4, 8'd7);
    s.run();
    tick(20);

    pulse_reset(6);
    env.flush();
    tick(10);

    chk("T20a", (pb.p0_aw_pending == 0 && pb.p0_w_pending == 0 && pb.p0_mw_grant === 1'b0),
        $sformatf("state survived reset: awp=%0d wp=%0d grant=%b",
                  pb.p0_aw_pending, pb.p0_w_pending, pb.p0_mw_grant));

    s = new_seq(0);
    s.push(WRITE, 4'd3, S0_BASE + 32'h900, 8'd1);
    s.run();
    drain();
    chk("T20b", (env.scb.n_wr_done > 0), "no traffic passes after reset");
  endtask
endclass

class axi4_test_t21 extends axi4_test;
  `TEST_CTOR("T21_RST_INFLIGHT")
  virtual task body();
    axi4_seq s;
    env.s_agt[0].drv.dam = 1;
    s = new_seq(0);
    s.push(WRITE, 4'd4, S0_BASE, 8'd1);
    s.run();
    tick(80);

    pulse_reset(6);
    env.flush();
    env.s_agt[0].drv.dam = 0;
    tick(10);

    chk("T21a", (pb.p0_aw_pending == 0), "aw_pending survived reset");

    s = new_seq(0);
    s.push(WRITE, 4'd5, S0_BASE + 32'hA00, 8'd1);
    s.run();
    drain();
    chk("T21b", (env.scb.n_wr_done > 0), "fabric dead after reset");
  endtask
endclass

class axi4_test_t22 extends axi4_test;
  `TEST_CTOR("T22_RST_TENURE")
  virtual task body();
    fork
      begin
        axi4_seq a = new_seq(0);
        a.push_burst_stream(WRITE, 4'd6, S0_BASE + 32'h000, 6, 8'd1);
        a.run();
      end
      begin
        axi4_seq b = new_seq(1);
        b.push_burst_stream(WRITE, 4'd7, S0_BASE + 32'h400, 6, 8'd1);
        b.run();
      end
    join
    tick(40);

    pulse_reset(6);
    env.flush();
    tick(10);

    chk("T22a", (pb.s0w_gnt_valid === 1'b0), "slave-port grant survived reset");

    begin
      axi4_seq c = new_seq(0);
      c.push(WRITE, 4'd8, S0_BASE + 32'hB00, 8'd1);
      c.run();
    end
    drain();
    chk("T22b", (env.scb.n_wr_done > 0), "fabric dead after a mid-tenure reset");
  endtask
endclass

// Read-grant handover. Mutation testing showed the stale-read-grant bug was caught
// only by luck, with no directed test: M0 completes one read to S0, goes quiet, and
// M1 asks for S0 later. The arbiter's speculative re-grant to M0 must self-clear.
class axi4_test_rd_handover extends axi4_test;
  `TEST_CTOR("RD_HANDOVER")
  virtual task body();
    axi4_seq s = new_seq(0);
    s.push(WRITE, 4'd1, S0_BASE + 32'h600, 8'd1);
    s.push(READ,  4'd2, S0_BASE + 32'h600, 8'd1);
    s.run();
    drain();
    tick(10);

    begin
      axi4_seq b = new_seq(1);
      b.push(READ, 4'd3, S0_BASE + 32'h600, 8'd1);
      b.run();
    end
    drain(2000);
    chk("RDH", (env.scb.n_rd_done == 2),
        $sformatf("M1 read never completed behind M0's stale grant (rd_done=%0d)",
                  env.scb.n_rd_done));
  endtask
endclass

// Reset-release window. srst_n lags raw arst_n by two cycles and the skids gate READY
// on srst, so a transaction presented in that window must WAIT rather than handshake
// into a resetting skid and vanish. rst_settle=0 removes the settle that hides it.
class axi4_test_rstwin extends axi4_test;
  `TEST_CTOR("RSTWIN")
  virtual task body();
    axi4_seq s;
    pb.rst_settle = 0;
    pb.rst_req    = 6;
    tick(2);
    env.flush();
    s = new_seq(0);
    s.push(WRITE, 4'd6, S0_BASE + 32'hC00, 8'd1);
    s.run();
    wait (pb.rst_req == 0);
    drain(4000);
    pb.rst_settle = 5;
    chk("RSTWIN", (env.scb.n_wr_done == 1),
        "transaction presented at reset release was lost");
  endtask
endclass

// aw_committed race: a presented AW must survive contention arriving at a saturated
// tenure. Deleting aw_committed passed every other test in both flows, because nothing
// made an AW wait at tenure_cnt >= TENURE_QUANTUM while the sibling's first same-dest
// AW arrived. The only symptom is a_aw_stable firing, so passing here means silence
// from the checker plus normal completion.
class axi4_test_committed extends axi4_test;
  `TEST_CTOR("COMMITTED")
  virtual task body();
    axi4_seq s;

    s = new_seq(0);
    s.push_burst_stream(WRITE, 4'd5, S0_BASE + 32'h000, TENURE_QUANTUM, 8'd1);
    s.run();
    drain();
    chk("CMTa", (pb.p0_tenure_cnt >= TENURE_QUANTUM && pb.p0_mw_grant === 1'b1),
        $sformatf("tenure=%0d grant=%b", pb.p0_tenure_cnt, pb.p0_mw_grant));

    env.s_agt[0].drv.aw_hold_pct = 100;
    s = new_seq(0);
    s.push(WRITE, 4'd5, S0_BASE + 32'h400, 8'd1);
    s.run();
    tick(10);

    begin
      axi4_seq b = new_seq(1);
      b.push(WRITE, 4'd9, S0_BASE + 32'h800, 8'd1);
      b.run();
    end
    tick(40);

    env.s_agt[0].drv.aw_hold_pct = 0;
  endtask
endclass

// Template for adding a directed test: write-then-readback at every size on both
// slaves with a DECERR tail. Nine lines of body plus one registration line in tb_top.
class axi4_test_example extends axi4_test;
  `TEST_CTOR("EXAMPLE")
  virtual task body();
    axi4_seq s = new_seq(0);
    for (int sz = 0; sz <= 2; sz++) begin
      s.push(WRITE, 4'(sz),   S0_BASE + 32'h900 + (sz<<6), 8'd3, 3'(sz));
      s.push(READ,  4'(sz),   S0_BASE + 32'h900 + (sz<<6), 8'd3, 3'(sz));
      s.push(WRITE, 4'(sz+8), S1_BASE + 32'h900 + (sz<<6), 8'd3, 3'(sz));
      s.push(READ,  4'(sz+8), S1_BASE + 32'h900 + (sz<<6), 8'd3, 3'(sz));
    end
    s.push(WRITE, 4'd15, BAD_BASE, 8'd1);
    s.run();
    drain();
  endtask
endclass

// ---- burst variety ----
class axi4_test_bursts extends axi4_test;
  `TEST_CTOR("BURSTS")
  virtual task body();
    axi4_seq s = new_seq(0);
    s.push(WRITE, 4'd1, S0_BASE + 32'h2000, 8'd1,   3'd2, 2'b10);
    s.push(WRITE, 4'd1, S0_BASE + 32'h2010, 8'd3,   3'd2, 2'b10);
    s.push(WRITE, 4'd1, S0_BASE + 32'h2040, 8'd7,   3'd2, 2'b10);
    s.push(WRITE, 4'd1, S0_BASE + 32'h2080, 8'd15,  3'd2, 2'b10);
    s.push(WRITE, 4'd2, S0_BASE + 32'h3000, 8'd3,   3'd2, 2'b00);
    s.push(READ,  4'd2, S0_BASE + 32'h3000, 8'd3,   3'd2, 2'b00);
    s.push(WRITE, 4'd3, S0_BASE + 32'h4000, 8'd3,   3'd0);
    s.push(WRITE, 4'd3, S0_BASE + 32'h4100, 8'd3,   3'd1);
    s.push(WRITE, 4'd4, S0_BASE + 32'h5000, 8'd255);
    s.push(WRITE, 4'd4, S0_BASE + 32'h0FC0, 8'd15);
    s.run();
    drain();

    s = new_seq(0);
    s.push(READ, 4'd5, S0_BASE + 32'h5000, 8'd255);
    s.push(READ, 4'd5, S0_BASE + 32'h4000, 8'd3, 3'd0);
    s.run();
  endtask
endclass

// ---- random: closes most of the coverage on its own ----
class axi4_test_random extends axi4_test;
  `TEST_CTOR("RANDOM")

  int n_txn = 200;

  virtual task body();
    void'($value$plusargs("NTXN=%d", n_txn));

    foreach (env.m_agt[i]) begin
      env.m_agt[i].drv.bready_pct = 70;
      env.m_agt[i].drv.rready_pct = 70;
    end
    foreach (env.s_agt[i]) begin
      env.s_agt[i].drv.aw_hold_pct = 25;
      env.s_agt[i].drv.ar_hold_pct = 25;
      env.s_agt[i].drv.ooo_pct     = 25;
    end
    slverr_window = 1;

    fork
      begin
        axi4_seq a = new_seq(0);
        a.n_items = n_txn;  a.mixed_dir = 1;  a.max_delay = 3;
        a.unaligned_pct = 15;
        a.run();
      end
      begin
        axi4_seq b = new_seq(1);
        b.n_items = n_txn;  b.mixed_dir = 1;  b.max_delay = 3;
        b.w_s0 = 60;  b.w_s1 = 25;  b.w_bad = 15;
        b.unaligned_pct = 15;
        b.run();
      end
    join
    slverr_window = 0;
  endtask
endclass
