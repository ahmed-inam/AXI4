// first-ever simulation of the crossbar RTL.
// T1: single write M0->S0, end to end.
// T2: M0 then M1 write to S0; slave returns both Bs back-to-back; M0 holds
//     BREADY high after its own response. Exposes the resp_return_mux
//     stale-selection READY leak if present.
`timescale 1ns/1ps

module tb_smoke;
  import axi4_pkg::*;

  logic aclk = 0, arst_n = 0;
  always #5 aclk = ~aclk;

  axi4_if #(.ID_W(ID_WIDTH)) m0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(ID_WIDTH)) m1 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s1 (.aclk(aclk), .arst_n(arst_n));

  axi4_xbar_top dut (.aclk(aclk), .arst_n(arst_n),
                     .m0(m0), .m1(m1), .s0(s0), .s1(s1));

  axi4_cov #(.NAME("tb_smoke")) u_cov (
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

  task automatic tick(int n = 1);
    repeat (n) @(posedge aclk);
  endtask

  typedef struct { logic [M_ID_W-1:0] id; } resp_t;
  resp_t s0_bq[$];
  int    s0_b_hold   = 0;
  int    s0_b_queued = 0;

  int    s0_aw_out   = 0;
  int    s0_bq_n     = 0;
  logic [M_ID_W-1:0] s0_aw_seen[$];

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) s0.awready <= 1'b0;
    else         s0.awready <= s0.awvalid && !s0.awready;
  end
  always_ff @(posedge aclk) begin
    if (arst_n && s0.awvalid && s0.awready) begin
      s0_aw_seen.push_back(s0.awid);
      s0_aw_out <= s0_aw_out + 1;
      $display("[%0t] S0 BFM: AW accepted id=5'b%b", $time, s0.awid);
    end
  end

  assign s0.wready = arst_n && (s0_aw_out > 0);
  always_ff @(posedge aclk) begin
    if (arst_n && s0.wvalid && s0.wready && s0.wlast) begin
      resp_t r;
      r.id = s0_aw_seen.pop_front();
      s0_bq.push_back(r);
      s0_aw_out    <= s0_aw_out - 1;
      s0_b_queued  <= s0_b_queued + 1;
      s0_bq_n      <= s0_bq_n + 1;
      $display("[%0t] S0 BFM: B queued for id=5'b%b", $time, r.id);
    end
  end

  always_comb begin
    s0.bvalid = (arst_n && s0_bq_n > 0 && s0_b_hold == 0);
    s0.bid    = s0.bvalid ? s0_bq[0].id : '0;
    s0.bresp  = 2'b00;
  end
  always_ff @(posedge aclk) begin
    if (arst_n && s0.bvalid && s0.bready) begin
      void'(s0_bq.pop_front());
      s0_bq_n <= s0_bq_n - 1;
    end
  end

  assign s1.awready = 1'b0;
  assign s1.wready  = 1'b0;
  assign s1.bvalid  = 1'b0;
  assign s1.bid     = '0;
  assign s1.bresp   = '0;
  assign s1.rvalid  = 1'b0;
  assign s1.rid     = '0;
  assign s1.rdata   = '0;
  assign s1.rresp   = '0;
  assign s1.rlast   = 1'b0;
  assign s0.rvalid  = 1'b0;
  assign s0.rid     = '0;
  assign s0.rdata   = '0;
  assign s0.rresp   = '0;
  assign s0.rlast   = 1'b0;

  task automatic drive_aw(virtual axi4_if #(.ID_W(ID_WIDTH)) vif,
                          logic [3:0] id, logic [31:0] addr, logic [7:0] len);
    @(negedge aclk);
    vif.awid    = id;   vif.awaddr = addr; vif.awlen = len;
    vif.awsize  = 3'd2; vif.awburst = 2'b01;
    vif.awvalid = 1'b1;
    do @(posedge aclk); while (!vif.awready);
    @(negedge aclk);
    vif.awvalid = 1'b0;
  endtask

  task automatic drive_w(virtual axi4_if #(.ID_W(ID_WIDTH)) vif,
                         int beats, logic [31:0] seed);
    for (int i = 0; i < beats; i++) begin
      @(negedge aclk);
      vif.wdata  = seed + i; vif.wstrb = '1;
      vif.wlast  = (i == beats-1);
      vif.wvalid = 1'b1;
      do @(posedge aclk); while (!vif.wready);
    end
    @(negedge aclk);
    vif.wvalid = 1'b0; vif.wlast = 1'b0;
  endtask

  int m0_b_count = 0, m1_b_count = 0;
  logic [3:0] m0_last_bid, m1_last_bid;
  always_ff @(posedge aclk) begin
    if (arst_n && m0.bvalid && m0.bready) begin
      m0_b_count <= m0_b_count + 1; m0_last_bid <= m0.bid;
      $display("[%0t] M0 got B: bid=%0d resp=%0d", $time, m0.bid, m0.bresp);
    end
    if (arst_n && m1.bvalid && m1.bready) begin
      m1_b_count <= m1_b_count + 1; m1_last_bid <= m1.bid;
      $display("[%0t] M1 got B: bid=%0d resp=%0d", $time, m1.bid, m1.bresp);
    end
  end

  always_ff @(posedge aclk) begin
    if (arst_n && s0.bvalid && s0.bready)
      $display("[%0t] S0 B popped: bid=5'b%b (tag=%0d)", $time, s0.bid, s0.bid[4]);
  end

  initial begin
    m0.awvalid = 0; m0.wvalid = 0; m0.arvalid = 0; m0.bready = 0; m0.rready = 0;
    m1.awvalid = 0; m1.wvalid = 0; m1.arvalid = 0; m1.bready = 0; m1.rready = 0;
    m0.awid=0; m0.awaddr=0; m0.awlen=0; m0.awsize=0; m0.awburst=0;
    m0.wdata=0; m0.wstrb=0; m0.wlast=0;
    m0.arid=0; m0.araddr=0; m0.arlen=0; m0.arsize=0; m0.arburst=0;
    m1.awid=0; m1.awaddr=0; m1.awlen=0; m1.awsize=0; m1.awburst=0;
    m1.wdata=0; m1.wstrb=0; m1.wlast=0;
    m1.arid=0; m1.araddr=0; m1.arlen=0; m1.arsize=0; m1.arburst=0;

    repeat (5) @(posedge aclk);
    arst_n = 1;
    repeat (4) @(posedge aclk);

    $display("=== T1: single write M0->S0, 4 beats, ID=3 ===");
    m0.bready = 1;
    fork
      drive_aw(m0, 4'd3, 32'h0000_1000, 8'd3);
      drive_w (m0, 4, 32'hA000_0000);
    join
    fork begin
      fork
        wait (m0_b_count == 1);
        begin tick(200); end
      join_any
      disable fork;
    end join
    if (m0_b_count != 1) begin
      $display("T1 FAIL: no B response after 200 cycles"); errors++;
    end
    else if (m0_last_bid !== 4'd3) begin
      $display("T1 FAIL: BID=%0d, expected 3", m0_last_bid); errors++;
    end
    else $display("T1 PASS");
    m0.bready = 0;
    tick(10);

    $display("=== T2: M0(ID=5) then M1(ID=9) -> S0, Bs back-to-back ===");
    @(negedge aclk); s0_b_hold = 1;
    m0.bready = 1;
    m1.bready = 1;
    fork
      drive_aw(m0, 4'd5, 32'h0000_2000, 8'd0);
      drive_w (m0, 1, 32'hB000_0000);
    join
    fork
      drive_aw(m1, 4'd9, 32'h0000_3000, 8'd0);
      drive_w (m1, 1, 32'hC000_0000);
    join

    forever begin
      @(negedge aclk);
      if (s0_b_queued == 3) break;
    end
    $display("[%0t] releasing 2 queued Bs back-to-back", $time);
    s0_b_hold = 0;
    fork begin
      fork
        wait (m0_b_count == 2 && m1_b_count == 1);
        begin tick(300); end
      join_any
      disable fork;
    end join
    if (m1_b_count != 1) begin
      $display("T2 FAIL: M1 never received its B (M0 extra=%0d). Response stolen/dropped.",
               m0_b_count - 1);
      errors++;
    end
    else $display("T2 PASS: both masters got their responses");

    tick(20);
    if (errors == 0) $display("ALL TESTS PASSED");
    else             $display("%0d TEST(S) FAILED", errors);
    u_cov.cov_report();
    $finish;
  end

  initial begin
    #100000;
    $display("GLOBAL TIMEOUT"); $finish;
  end
endmodule
