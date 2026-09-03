// directed tests for the grant lifecycle and admission gates.
// Whitebox: these probe DUT internals, because most of what is being checked is
// a decision the fabric makes rather than something visible on the pins.
//
//   T9   !mw_full on acquisition -- destination switch with responses trailing
//   T10  grant RETAINED when uncontested (w_pending==0 is permission, not command)
//   T11  grant released on destination change (needs_diff)
//   T12  grant released under contention once the tenure is spent
//   T13  tenure quantum: >= TENURE_QUANTUM admissions before contention can close
//   T14  DECERR AW must wait for the grant to release
//   T15  mw_full: MAX_OUTSTANDING accepted, next blocked until a B returns
//   T16  tracker full: 3 distinct IDs with NUM_THREADS = 2
//   T17  same ID same dest pipelines; same ID different dest blocks
//   T18  W beats arriving before their AW (w_beat_ok)
`timescale 1ns/1ps

module tb_grant;
  import axi4_pkg::*;

  logic aclk = 0, arst_n = 0;
  always #5 aclk = ~aclk;

  axi4_if #(.ID_W(ID_WIDTH)) m0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(ID_WIDTH)) m1 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s1 (.aclk(aclk), .arst_n(arst_n));

  axi4_xbar_top dut (.aclk(aclk), .arst_n(arst_n),
                     .m0(m0), .m1(m1), .s0(s0), .s1(s1));

  axi4_cov #(.NAME("tb_grant")) u_cov (
    .aclk(aclk), .arst_n(arst_n),
    .p0_awp (dut.g_mport[0].u_wr_ctrl.aw_pending),
    .p1_awp (dut.g_mport[1].u_wr_ctrl.aw_pending),
    .p0_wp  (dut.g_mport[0].u_wr_ctrl.w_pending),
    .p1_wp  (dut.g_mport[1].u_wr_ctrl.w_pending),
    .p0_ten (dut.g_mport[0].u_wr_ctrl.tenure_cnt),
    .p1_ten (dut.g_mport[1].u_wr_ctrl.tenure_cnt),
    .p0_gnt (dut.mw_grant[0]),          .p1_gnt (dut.mw_grant[1]),
    .p0_dest(dut.mw_dest[0]),           .p1_dest(dut.mw_dest[1]),
    .p0_full(dut.g_mport[0].u_wr_ctrl.mw_full),
    .p1_full(dut.g_mport[1].u_wr_ctrl.mw_full),
    .p0_cont(dut.g_mport[0].u_wr_ctrl.contested),
    .p1_cont(dut.g_mport[1].u_wr_ctrl.contested),
    .p0_close(dut.g_mport[0].u_wr_ctrl.close_admission),
    .p1_close(dut.g_mport[1].u_wr_ctrl.close_admission),
    .p0_cmt (dut.g_mport[0].u_wr_ctrl.aw_committed),
    .p1_cmt (dut.g_mport[1].u_wr_ctrl.aw_committed),
    .p0_throk(dut.wr_thr_ok[0]),        .p1_throk(dut.wr_thr_ok[1]),
    .p0_admit(dut.g_mport[0].u_wr_ctrl.aw_admit),
    .p1_admit(dut.g_mport[1].u_wr_ctrl.aw_admit),
    .p0_rel (dut.g_mport[0].u_wr_ctrl.mw_release),
    .p1_rel (dut.g_mport[1].u_wr_ctrl.mw_release),
    .p0_awdest(dut.aw_dest[0]),         .p1_awdest(dut.aw_dest[1]),
    .p0_awv (dut.aw_v[0]),              .p1_awv (dut.aw_v[1]),
    .r0_arp (dut.g_mport[0].u_rd_ctrl.ar_pending),
    .r1_arp (dut.g_mport[1].u_rd_ctrl.ar_pending),
    .r0_full(dut.g_mport[0].u_rd_ctrl.ar_full),
    .r1_full(dut.g_mport[1].u_rd_ctrl.ar_full),
    .t0w_act({1'b0, 1'b0} + dut.g_mport[0].u_wr_thr.active[0]
                          + dut.g_mport[0].u_wr_thr.active[1]),
    .t1w_act({1'b0, 1'b0} + dut.g_mport[1].u_wr_thr.active[0]
                          + dut.g_mport[1].u_wr_thr.active[1]),
    .t0r_act({1'b0, 1'b0} + dut.g_mport[0].u_rd_thr.active[0]
                          + dut.g_mport[0].u_rd_thr.active[1]),
    .t1r_act({1'b0, 1'b0} + dut.g_mport[1].u_rd_thr.active[0]
                          + dut.g_mport[1].u_rd_thr.active[1]),
    .s0w_gnt(dut.g_sport[0].u_swr.arb_gnt), .s1w_gnt(dut.g_sport[1].u_swr.arb_gnt),
    .s0r_gnt(dut.g_sport[0].u_srd.arb_gnt), .s1r_gnt(dut.g_sport[1].u_srd.arb_gnt),
    .s0w_gv (dut.g_sport[0].u_swr.gnt_valid), .s1w_gv(dut.g_sport[1].u_swr.gnt_valid),
    .s0r_gv (dut.g_sport[0].u_srd.gnt_valid), .s1r_gv(dut.g_sport[1].u_srd.gnt_valid),
    .b0_req (dut.g_mport[0].u_b_mux.req),  .b1_req(dut.g_mport[1].u_b_mux.req),
    .r0_req (dut.g_mport[0].u_r_mux.req),  .r1_req(dut.g_mport[1].u_r_mux.req),
    .r0_mid (dut.g_mport[0].u_r_mux.mid_burst),
    .r1_mid (dut.g_mport[1].u_r_mux.mid_burst),
    .sk_aw0 (dut.g_mport[0].u_aw_skid.state),
    .sk_w0  (dut.g_mport[0].u_w_skid.state),
    .sk_ar0 (dut.g_mport[0].u_ar_skid.state),
    .sk_b0  (dut.g_sport[0].u_b_skid.state),
    .sk_r0  (dut.g_sport[0].u_r_skid.state),
    .aw_hs  (m0.awvalid && m0.awready), .ar_hs(m0.arvalid && m0.arready),
    .aw_len (m0.awlen),   .ar_len(m0.arlen),
    .aw_burst(m0.awburst),.ar_burst(m0.arburst),
    .aw_size(m0.awsize),  .ar_size(m0.arsize),
    .aw_dest_pin(dut.aw_dest[0]), .ar_dest_pin(dut.ar_dest[0]),
    .dw0_busy(dut.dw_busy[0]), .dr0_busy(dut.dr_busy[0]));

  int errors = 0;
  task automatic tick(int n = 1); repeat (n) @(posedge aclk); endtask
  task automatic chk(string name, bit cond, string msg);
    if (cond) $display("  %s PASS", name);
    else begin $display("  %s FAIL: %s", name, msg); errors++; end
  endtask

  `define P0 dut.g_mport[0].u_wr_ctrl
  `define P1 dut.g_mport[1].u_wr_ctrl

  int s0_aw_out = 0, s0_b_n = 0, s0_ar_out = 0;
  int s1_aw_out = 0, s1_b_n = 0, s1_ar_out = 0;
  int s0_b_hold = 0, s1_b_hold = 0;
  logic [M_ID_W-1:0] s0_awq[$], s0_bq[$], s1_awq[$], s1_bq[$];

  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s0.awready <= 1'b0;
    else         s0.awready <= s0.awvalid && !s0.awready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s1.awready <= 1'b0;
    else         s1.awready <= s1.awvalid && !s1.awready;

  assign s0.wready = arst_n && (s0_aw_out > 0);
  assign s1.wready = arst_n && (s1_aw_out > 0);

  always_ff @(posedge aclk) if (arst_n) begin
    automatic int a0 = 0, q0 = 0, a1 = 0, q1 = 0;
    if (s0.awvalid && s0.awready) begin s0_awq.push_back(s0.awid); a0++; end
    if (s0.wvalid && s0.wready && s0.wlast) begin
      s0_bq.push_back(s0_awq.pop_front()); a0--; q0++;
    end
    if (s0.bvalid && s0.bready) begin void'(s0_bq.pop_front()); q0--; end
    s0_aw_out <= s0_aw_out + a0;  s0_b_n <= s0_b_n + q0;

    if (s1.awvalid && s1.awready) begin s1_awq.push_back(s1.awid); a1++; end
    if (s1.wvalid && s1.wready && s1.wlast) begin
      s1_bq.push_back(s1_awq.pop_front()); a1--; q1++;
    end
    if (s1.bvalid && s1.bready) begin void'(s1_bq.pop_front()); q1--; end
    s1_aw_out <= s1_aw_out + a1;  s1_b_n <= s1_b_n + q1;
  end

  always_comb begin
    s0.bvalid = arst_n && (s0_b_n > 0) && (s0_b_hold == 0);
    s0.bid    = s0.bvalid ? s0_bq[0] : '0;
    s0.bresp  = 2'b00;
    s1.bvalid = arst_n && (s1_b_n > 0) && (s1_b_hold == 0);
    s1.bid    = s1.bvalid ? s1_bq[0] : '0;
    s1.bresp  = 2'b00;
  end

  assign s0.arready = 1'b0; assign s1.arready = 1'b0;
  assign s0.rvalid = 1'b0; assign s0.rid='0; assign s0.rdata='0;
  assign s0.rresp='0; assign s0.rlast=1'b0;
  assign s1.rvalid = 1'b0; assign s1.rid='0; assign s1.rdata='0;
  assign s1.rresp='0; assign s1.rlast=1'b0;

  int m0_b = 0, m1_b = 0;
  int m0_admits = 0, m1_admits = 0;
  logic [3:0] m0_last_bid; logic [1:0] m0_last_bresp;

  always_ff @(posedge aclk) if (arst_n) begin
    if (m0.bvalid && m0.bready) begin
      m0_b <= m0_b + 1; m0_last_bid <= m0.bid; m0_last_bresp <= m0.bresp;
    end
    if (m1.bvalid && m1.bready) m1_b <= m1_b + 1;
    if (`P0.aw_admit) m0_admits <= m0_admits + 1;
    if (`P1.aw_admit) m1_admits <= m1_admits + 1;
  end

  task automatic aw(virtual axi4_if #(.ID_W(ID_WIDTH)) v,
                    logic [3:0] id, logic [31:0] addr, logic [7:0] len);
    @(negedge aclk);
    v.awid=id; v.awaddr=addr; v.awlen=len; v.awsize=3'd2; v.awburst=2'b01;
    v.awvalid=1'b1;
    do @(posedge aclk); while (!v.awready);
    @(negedge aclk); v.awvalid=1'b0;
  endtask

  // Starts an AW and does not wait -- needed where a test must observe the port while
  // an AW is presented but not yet accepted.
  task automatic aw_nb(virtual axi4_if #(.ID_W(ID_WIDTH)) v,
                       logic [3:0] id, logic [31:0] addr, logic [7:0] len);
    @(negedge aclk);
    v.awid=id; v.awaddr=addr; v.awlen=len; v.awsize=3'd2; v.awburst=2'b01;
    v.awvalid=1'b1;
  endtask

  task automatic wr(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int beats);
    for (int i = 0; i < beats; i++) begin
      @(negedge aclk);
      v.wdata=32'hD000_0000+i; v.wstrb='1; v.wlast=(i==beats-1); v.wvalid=1'b1;
      do @(posedge aclk); while (!v.wready);
    end
    @(negedge aclk); v.wvalid=1'b0; v.wlast=1'b0;
  endtask

  task automatic burst(virtual axi4_if #(.ID_W(ID_WIDTH)) v,
                       logic [3:0] id, logic [31:0] addr, int beats);
    fork
      aw(v, id, addr, beats-1);
      wr(v, beats);
    join
  endtask

  localparam logic [31:0] A_S0 = 32'h0000_1000;
  localparam logic [31:0] A_S1 = 32'h1000_1000;
  localparam logic [31:0] A_BAD = 32'hF000_0000;

  initial begin
    m0.awvalid=0; m0.wvalid=0; m0.arvalid=0; m0.bready=1; m0.rready=1;
    m1.awvalid=0; m1.wvalid=0; m1.arvalid=0; m1.bready=1; m1.rready=1;
    m0.awid=0; m0.awaddr=0; m0.awlen=0; m0.awsize=0; m0.awburst=0;
    m0.wdata=0; m0.wstrb=0; m0.wlast=0;
    m0.arid=0; m0.araddr=0; m0.arlen=0; m0.arsize=0; m0.arburst=0;
    m1.awid=0; m1.awaddr=0; m1.awlen=0; m1.awsize=0; m1.awburst=0;
    m1.wdata=0; m1.wstrb=0; m1.wlast=0;
    m1.arid=0; m1.araddr=0; m1.arlen=0; m1.arsize=0; m1.arburst=0;
    tick(5); arst_n = 1; tick(5);

    // The S1 grant must not be requested until a response frees a slot, or the port
    // holds a slave it cannot drive.
    $display("\n=== T9: destination switch with responses trailing (!mw_full gate) ===");
    begin
      bit req_while_full = 0;
      s0_b_hold = 1;
      for (int i = 0; i < 4; i++) burst(m0, 4'd1, A_S0 + i*64, 2);
      tick(2);
      chk("T9a", (`P0.aw_pending == 4),
          $sformatf("aw_pending=%0d, wanted 4 (MAX_OUTSTANDING)", `P0.aw_pending));

      fork
        burst(m0, 4'd2, A_S1, 2);
        begin
          for (int i = 0; i < 20; i++) begin
            tick();
            if (`P0.arb_req != 2'b00 && `P0.mw_full) req_while_full = 1;
          end
          chk("T9b", !req_while_full,
              "arbiter requested while mw_full -- acquisition gate broken");
          chk("T9c", (`P0.mw_grant == 1'b0 || `P0.mw_dest == DEST_S0),
              "took the S1 grant while still full");
          s0_b_hold = 0;
        end
      join
      for (int i = 0; i < 600 && m0_b < 5; i++) tick();
      chk("T9d", (m0_b == 5), $sformatf("only %0d/5 responses after release", m0_b));
    end
    tick(20);

    // w_pending == 0 is permission to release, not a command to.
    $display("\n=== T10: grant retained when uncontested ===");
    begin
      burst(m0, 4'd3, A_S0, 2);
      tick(3);
      chk("T10", (`P0.mw_grant == 1'b1 && `P0.mw_dest == DEST_S0),
          $sformatf("grant=%b dest=%0d -- released with nobody contesting",
                    `P0.mw_grant, `P0.mw_dest));
    end
    tick(20);

    $display("\n=== T11: grant released on destination change ===");
    begin
      bit saw_release = 0;
      chk("T11a", (`P0.mw_grant == 1'b1), "precondition: expected to still hold S0");
      fork
        burst(m0, 4'd4, A_S1, 2);
        begin
          for (int i = 0; i < 200; i++) begin
            tick();
            if (`P0.mw_release) saw_release = 1;
          end
        end
      join
      chk("T11b", saw_release, "mw_release never fired on a destination change");
      for (int i = 0; i < 400 && m0_b < 7; i++) tick();
      chk("T11c", (m0_b == 7), $sformatf("burst to S1 did not complete (m0_b=%0d)", m0_b));
    end
    tick(20);

    $display("\n=== T12/T13: tenure quantum and handover under contention ===");
    begin
      int a0 = m0_admits, a1 = m1_admits;
      int max_ten = 0;
      bit handover = 0;
      logic prev_gnt;
      prev_gnt = dut.g_sport[0].u_swr.arb_gnt[0];
      fork
        begin for (int i = 0; i < 12; i++) aw(m0, 4'd5, A_S0 + i*64, 8'd1); end
        begin for (int i = 0; i < 12; i++) wr(m0, 2);                       end
        begin for (int i = 0; i < 12; i++) aw(m1, 4'd6, A_S0 + i*64, 8'd1); end
        begin for (int i = 0; i < 12; i++) wr(m1, 2);                       end
        begin
          for (int i = 0; i < 4000; i++) begin
            tick();
            if (`P0.tenure_cnt > max_ten) max_ten = `P0.tenure_cnt;
            if (dut.g_sport[0].u_swr.arb_gnt[0] != prev_gnt) handover = 1;
            prev_gnt = dut.g_sport[0].u_swr.arb_gnt[0];
          end
        end
      join_any
      for (int i = 0; i < 4000 && (m0_b < 7+12 || m1_b < 12); i++) tick();
      chk("T12", (m0_b >= 7+12 && m1_b >= 12),
          $sformatf("M0 %0d/12, M1 %0d/12 -- starvation or wedge under contention",
                    m0_b-7, m1_b));
      chk("T13a", handover, "grant never handed over -- tenure quantum not forcing release");
      chk("T13b", (max_ten >= TENURE_QUANTUM),
          $sformatf("tenure_cnt peaked at %0d, expected to reach %0d",
                    max_ten, TENURE_QUANTUM));
      disable fork;
    end
    tick(30);

    $display("\n=== T14: DECERR admission waits for grant release ===");
    begin
      int b0 = m0_b;
      bit bad_admit = 0;
      burst(m0, 4'd7, A_S0, 2);
      tick(3);
      fork
        burst(m0, 4'd8, A_BAD, 2);
        begin
          for (int i = 0; i < 200; i++) begin
            tick();
            if (`P0.aw_admit && (`P0.aw_dest == DEST_DECERR) && `P0.mw_grant)
              bad_admit = 1;
          end
        end
      join_any
      for (int i = 0; i < 600 && m0_b < b0+2; i++) tick();
      chk("T14a", !bad_admit, "DECERR admitted while a grant was still held");
      chk("T14b", (m0_b == b0+2 && m0_last_bresp == 2'b11),
          $sformatf("m0_b=%0d bresp=%b -- DECERR did not complete",
                    m0_b-b0, m0_last_bresp));
      disable fork;
    end
    tick(20);

    $display("\n=== T15: mw_full blocks the MAX_OUTSTANDING+1'th ===");
    begin
      int b0 = m0_b;
      s0_b_hold = 1;
      for (int i = 0; i < 4; i++) burst(m0, 4'd9, A_S0 + i*64, 2);
      tick(2);
      chk("T15a", (`P0.aw_pending == MAX_OUTSTANDING && `P0.mw_full),
          $sformatf("aw_pending=%0d mw_full=%b", `P0.aw_pending, `P0.mw_full));
      fork
        burst(m0, 4'd9, A_S0 + 32'h400, 2);
        begin
          bit admitted_while_full = 0;
          for (int i = 0; i < 20; i++) begin
            tick();
            if (`P0.aw_admit && `P0.mw_full) admitted_while_full = 1;
          end
          chk("T15b", !admitted_while_full,
              "an AW was admitted while at the outstanding limit");
          s0_b_hold = 0;
        end
      join
      for (int i = 0; i < 800 && m0_b < b0+5; i++) tick();
      chk("T15c", (m0_b == b0+5),
          $sformatf("only %0d/5 completed after the limit lifted", m0_b-b0));
    end
    tick(20);

    // Must block on thread allocation while still well clear of mw_full.
    $display("\n=== T16: tracker full on a third distinct ID ===");
    begin
      int b0 = m0_b;
      bit blocked_on_thr = 0;
      s0_b_hold = 1;
      burst(m0, 4'd1, A_S0,       2);
      burst(m0, 4'd2, A_S0 + 64,  2);
      tick(2);
      chk("T16a", (`P0.aw_pending == 2 && !`P0.mw_full),
          $sformatf("aw_pending=%0d mw_full=%b -- want 2 and clear of the limit",
                    `P0.aw_pending, `P0.mw_full));
      fork
        burst(m0, 4'd3, A_S0 + 128, 2);
        begin
          bit admitted = 0;
          for (int i = 0; i < 20; i++) begin
            tick();
            if (!`P0.thr_ok && !`P0.mw_full) blocked_on_thr = 1;
            if (`P0.aw_admit) admitted = 1;
          end
          chk("T16b", blocked_on_thr,
              "third distinct ID was not blocked on thread allocation");
          chk("T16c", !admitted, "third ID admitted with no free tracker slot");
          s0_b_hold = 0;
        end
      join
      for (int i = 0; i < 800 && m0_b < b0+3; i++) tick();
      chk("T16d", (m0_b == b0+3),
          $sformatf("only %0d/3 completed after slots freed", m0_b-b0));
    end
    tick(20);

    $display("\n=== T17: same-ID ordering ===");
    begin
      int b0 = m0_b;
      bit blocked = 0;
      s0_b_hold = 1;
      burst(m0, 4'd4, A_S0,      2);
      burst(m0, 4'd4, A_S0 + 64, 2);
      tick(2);
      chk("T17a", (`P0.aw_pending == 2),
          $sformatf("aw_pending=%0d -- same ID same dest should pipeline",
                    `P0.aw_pending));
      fork
        burst(m0, 4'd4, A_S1, 2);
        begin
          for (int i = 0; i < 20; i++) begin
            tick();
            if (!`P0.thr_ok) blocked = 1;
          end
          chk("T17b", blocked, "same ID to a different slave was not blocked");
          s0_b_hold = 0;
        end
      join
      for (int i = 0; i < 900 && m0_b < b0+3; i++) tick();
      chk("T17c", (m0_b == b0+3),
          $sformatf("only %0d/3 completed after the block cleared", m0_b-b0));
    end
    tick(20);

    // w_beat_ok must hold beats until the AW is admitted, then route them correctly.
    $display("\n=== T18: W beats presented before their AW ===");
    begin
      int b0 = m0_b;
      fork
        begin
          wr(m0, 2);
        end
        begin
          tick(6);
          aw(m0, 4'd5, A_S0, 8'd1);
        end
      join
      for (int i = 0; i < 600 && m0_b < b0+1; i++) tick();
      chk("T18", (m0_b == b0+1 && m0_last_bid == 4'd5),
          $sformatf("m0_b=%0d bid=%0d -- early W beats mis-routed or lost",
                    m0_b-b0, m0_last_bid));
    end

    tick(20);
    $display("\n==================================");
    if (errors == 0) $display("ALL GRANT-LIFECYCLE TESTS PASSED");
    else             $display("%0d CHECK(S) FAILED", errors);
    $display("==================================");
    u_cov.cov_report();
    $finish;
  end

  initial begin
    #400000;
    $display("GLOBAL TIMEOUT -- m0_b=%0d m1_b=%0d P0.grant=%b P0.awp=%0d P0.wp=%0d",
             m0_b, m1_b, `P0.mw_grant, `P0.aw_pending, `P0.w_pending);
    $finish;
  end
endmodule
