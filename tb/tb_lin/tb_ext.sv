// coverage for the paths tb_smoke never touches.
//   T3  single read  M0 -> S0
//   T4  DECERR write M0 (bad address, multi-beat: all beats must drain)
//   T5  DECERR read   M0 (bad address: ARLEN+1 beats, RLAST on the last)
//   T6  contention: both masters stream writes to S0 (tenure quantum, handover)
//   T7  both slaves return reads to M0 at once (return-mux fairness)
//   T8  R-path twin of tb_smoke's T2: back-to-back R bursts for different masters
//
// Slave BFMs default to registered AWREADY/ARREADY and randomised RVALID gaps,
// because every bug found in this design so far hid behind idealised endpoints.
`timescale 1ns/1ps

module tb_ext;
  import axi4_pkg::*;

  logic aclk = 0, arst_n = 0;
  always #5 aclk = ~aclk;

  axi4_if #(.ID_W(ID_WIDTH)) m0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(ID_WIDTH)) m1 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s1 (.aclk(aclk), .arst_n(arst_n));

  axi4_xbar_top dut (.aclk(aclk), .arst_n(arst_n),
                     .m0(m0), .m1(m1), .s0(s0), .s1(s1));

  axi4_cov #(.NAME("tb_ext")) u_cov (
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

  bit bp_on = 0;
  always_ff @(posedge aclk) begin
    if (bp_on) begin
      m0.bready <= ($urandom_range(0,3) != 0);
      m1.bready <= ($urandom_range(0,3) != 0);
      m0.rready <= ($urandom_range(0,3) != 0);
      m1.rready <= ($urandom_range(0,3) != 0);
    end
  end
  task automatic tick(int n = 1); repeat (n) @(posedge aclk); endtask

  int s0_aw_out = 0, s0_b_n = 0, s0_ar_out = 0, s0_r_beats = 0;
  logic [M_ID_W-1:0] s0_awq[$], s0_bq[$], s0_arq[$];
  logic [7:0]        s0_arlenq[$];
  logic [M_ID_W-1:0] s0_r_id = 0;
  logic [7:0]        s0_r_left = 0;
  int                s0_gap = 0;

  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s0.awready <= 1'b0;
    else         s0.awready <= s0.awvalid && !s0.awready;

  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s0.arready <= 1'b0;
    else         s0.arready <= s0.arvalid && !s0.arready;

  logic s0_wstall = 0, s1_wstall = 0;
  always_ff @(posedge aclk) begin
    s0_wstall <= ($urandom_range(0,3) == 0);
    s1_wstall <= ($urandom_range(0,3) == 0);
  end
  assign s0.wready = arst_n && (s0_aw_out > 0) && !s0_wstall;

  always_ff @(posedge aclk) begin
    if (arst_n) begin
      automatic int aw_d = 0, b_d = 0;
      if (s0.awvalid && s0.awready) begin
        s0_awq.push_back(s0.awid); aw_d++;
      end
      if (s0.wvalid && s0.wready && s0.wlast) begin
        s0_bq.push_back(s0_awq.pop_front()); aw_d--; b_d++;
      end
      if (s0.bvalid && s0.bready) begin
        void'(s0_bq.pop_front()); b_d--;
      end
      s0_aw_out <= s0_aw_out + aw_d;
      s0_b_n    <= s0_b_n    + b_d;
      if (s0.arvalid && s0.arready) begin
        s0_arq.push_back(s0.arid); s0_arlenq.push_back(s0.arlen);
        s0_ar_out <= s0_ar_out + 1;
      end
    end
  end

  always_comb begin
    s0.bvalid = arst_n && (s0_b_n > 0);
    s0.bid    = s0.bvalid ? s0_bq[0] : '0;
    s0.bresp  = 2'b00;
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s0.rvalid <= 1'b0; s0.rlast <= 1'b0; s0.rid <= '0;
      s0.rdata  <= '0;   s0.rresp <= 2'b00; s0_r_left <= 0; s0_gap <= 0;
    end
    else if (s0.rvalid && s0.rready) begin
      if (s0_r_left != 0) begin
        s0_r_left <= s0_r_left - 1;
        if ($urandom_range(0,2) == 0) begin s0.rvalid <= 1'b0; s0_gap <= 2; end
        else begin s0.rdata <= s0.rdata + 1; s0.rlast <= (s0_r_left == 1); end
      end
      else begin
        s0.rvalid <= 1'b0; s0.rlast <= 1'b0;
        s0_ar_out <= s0_ar_out - 1;
        void'(s0_arq.pop_front()); void'(s0_arlenq.pop_front());
      end
    end
    else if (s0_gap != 0) begin
      s0_gap <= s0_gap - 1;
      if (s0_gap == 1) begin
        s0.rvalid <= 1'b1; s0.rdata <= s0.rdata + 1; s0.rlast <= (s0_r_left == 0);
      end
    end
    else if (!s0.rvalid && s0_ar_out > 0) begin
      s0.rvalid <= 1'b1; s0.rid <= s0_arq[0];
      s0_r_left <= s0_arlenq[0];
      s0.rlast  <= (s0_arlenq[0] == 0);
      s0.rdata  <= 32'hA000_0000;
    end
  end

  int s1_aw_out = 0, s1_b_n = 0, s1_ar_out = 0;
  logic [M_ID_W-1:0] s1_awq[$], s1_bq[$], s1_arq[$];
  logic [7:0]        s1_arlenq[$];
  logic [7:0]        s1_r_left = 0;

  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s1.awready <= 1'b0;
    else         s1.awready <= s1.awvalid && !s1.awready;

  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s1.arready <= 1'b0;
    else         s1.arready <= s1.arvalid && !s1.arready;

  assign s1.wready = arst_n && (s1_aw_out > 0) && !s1_wstall;

  always_ff @(posedge aclk) begin
    if (arst_n) begin
      automatic int aw_d = 0, b_d = 0;
      if (s1.awvalid && s1.awready) begin
        s1_awq.push_back(s1.awid); aw_d++;
      end
      if (s1.wvalid && s1.wready && s1.wlast) begin
        s1_bq.push_back(s1_awq.pop_front()); aw_d--; b_d++;
      end
      if (s1.bvalid && s1.bready) begin
        void'(s1_bq.pop_front()); b_d--;
      end
      s1_aw_out <= s1_aw_out + aw_d;
      s1_b_n    <= s1_b_n    + b_d;
      if (s1.arvalid && s1.arready) begin
        s1_arq.push_back(s1.arid); s1_arlenq.push_back(s1.arlen);
        s1_ar_out <= s1_ar_out + 1;
      end
    end
  end

  always_comb begin
    s1.bvalid = arst_n && (s1_b_n > 0);
    s1.bid    = s1.bvalid ? s1_bq[0] : '0;
    s1.bresp  = 2'b00;
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s1.rvalid <= 1'b0; s1.rlast <= 1'b0; s1.rid <= '0;
      s1.rdata  <= '0;   s1.rresp <= 2'b00; s1_r_left <= 0;
    end
    else if (s1.rvalid && s1.rready) begin
      if (s1_r_left != 0) begin
        s1_r_left <= s1_r_left - 1;
        s1.rdata  <= s1.rdata + 1;
        s1.rlast  <= (s1_r_left == 1);
      end
      else begin
        s1.rvalid <= 1'b0; s1.rlast <= 1'b0;
        s1_ar_out <= s1_ar_out - 1;
        void'(s1_arq.pop_front()); void'(s1_arlenq.pop_front());
      end
    end
    else if (!s1.rvalid && s1_ar_out > 0) begin
      s1.rvalid <= 1'b1; s1.rid <= s1_arq[0];
      s1_r_left <= s1_arlenq[0];
      s1.rlast  <= (s1_arlenq[0] == 0);
      s1.rdata  <= 32'hB000_0000;
    end
  end

  int m0_b = 0, m1_b = 0, m0_r = 0, m1_r = 0, m0_rlast = 0, m1_rlast = 0;
  logic [1:0] m0_last_bresp, m0_last_rresp;
  logic [3:0] m0_last_bid, m0_last_rid;

  always_ff @(posedge aclk) if (arst_n) begin
    if (m0.bvalid && m0.bready) begin
      m0_b <= m0_b + 1; m0_last_bid <= m0.bid; m0_last_bresp <= m0.bresp;
    end
    if (m1.bvalid && m1.bready) m1_b <= m1_b + 1;
    if (m0.rvalid && m0.rready) begin
      m0_r <= m0_r + 1; m0_last_rid <= m0.rid; m0_last_rresp <= m0.rresp;
      if (m0.rlast) m0_rlast <= m0_rlast + 1;
    end
    if (m1.rvalid && m1.rready) begin
      m1_r <= m1_r + 1;
      if (m1.rlast) m1_rlast <= m1_rlast + 1;
    end
  end

  task automatic aw(virtual axi4_if #(.ID_W(ID_WIDTH)) v,
                    logic [3:0] id, logic [31:0] addr, logic [7:0] len);
    @(negedge aclk);
    v.awid = id; v.awaddr = addr; v.awlen = len;
    v.awsize = 3'd2; v.awburst = 2'b01; v.awvalid = 1'b1;
    do @(posedge aclk); while (!v.awready);
    @(negedge aclk); v.awvalid = 1'b0;
  endtask

  task automatic wr(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int beats);
    for (int i = 0; i < beats; i++) begin
      @(negedge aclk);
      v.wdata = 32'hD000_0000 + i; v.wstrb = '1;
      v.wlast = (i == beats-1); v.wvalid = 1'b1;
      do @(posedge aclk); while (!v.wready);
    end
    @(negedge aclk); v.wvalid = 1'b0; v.wlast = 1'b0;
  endtask

  task automatic ar(virtual axi4_if #(.ID_W(ID_WIDTH)) v,
                    logic [3:0] id, logic [31:0] addr, logic [7:0] len);
    @(negedge aclk);
    v.arid = id; v.araddr = addr; v.arlen = len;
    v.arsize = 3'd2; v.arburst = 2'b01; v.arvalid = 1'b1;
    do @(posedge aclk); while (!v.arready);
    @(negedge aclk); v.arvalid = 1'b0;
  endtask

  task automatic chk(string name, bit cond, string msg);
    if (cond) $display("%s PASS", name);
    else begin $display("%s FAIL: %s", name, msg); errors++; end
  endtask

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

    $display("\n=== T3: single read M0->S0, 4 beats, ID=2 ===");
    ar(m0, 4'd2, 32'h0000_1000, 8'd3);
    for (int i = 0; i < 400 && m0_rlast == 0; i++) tick();
    chk("T3", (m0_r == 4 && m0_rlast == 1 && m0_last_rid == 4'd2),
        $sformatf("beats=%0d rlast=%0d rid=%0d (want 4,1,2)", m0_r, m0_rlast, m0_last_rid));
    tick(10);

    $display("\n=== T4: DECERR write M0, bad addr, 4 beats ===");
    begin
      int b0 = m0_b;
      fork
        aw(m0, 4'd7, 32'hF000_0000, 8'd3);
        wr(m0, 4);
      join
      for (int i = 0; i < 400 && m0_b == b0; i++) tick();
      chk("T4", (m0_b == b0+1 && m0_last_bid == 4'd7 && m0_last_bresp == 2'b11),
          $sformatf("b=%0d bid=%0d bresp=%b (want +1, 7, 11)",
                    m0_b-b0, m0_last_bid, m0_last_bresp));
    end
    tick(10);

    $display("\n=== T5: DECERR read M0, bad addr, ARLEN=3 ===");
    begin
      int r0 = m0_r, l0 = m0_rlast;
      ar(m0, 4'd5, 32'hE000_0000, 8'd3);
      for (int i = 0; i < 400 && m0_rlast == l0; i++) tick();
      chk("T5", (m0_r == r0+4 && m0_rlast == l0+1 &&
                 m0_last_rid == 4'd5 && m0_last_rresp == 2'b11),
          $sformatf("beats=%0d rlast=%0d rid=%0d rresp=%b (want 4,1,5,11)",
                    m0_r-r0, m0_rlast-l0, m0_last_rid, m0_last_rresp));
    end
    tick(10);

    // T6: from here on, masters stall randomly
    bp_on = 1;
    $display("\n=== T6: both masters stream 8 writes each to S0 ===");
    begin
      int b0 = m0_b, b1 = m1_b;
      fork
        begin
          for (int i = 0; i < 8; i++) begin
            fork
              aw(m0, 4'd1, 32'h0000_4000 + i*64, 8'd1);
              wr(m0, 2);
            join
          end
        end
        begin
          for (int i = 0; i < 8; i++) begin
            fork
              aw(m1, 4'd2, 32'h0000_5000 + i*64, 8'd1);
              wr(m1, 2);
            join
          end
        end
      join
      for (int i = 0; i < 3000 && (m0_b < b0+8 || m1_b < b1+8); i++) tick();
      chk("T6", (m0_b == b0+8 && m1_b == b1+8),
          $sformatf("M0 got %0d/8, M1 got %0d/8 -- starvation or wedge",
                    m0_b-b0, m1_b-b1));
    end
    tick(20);

    $display("\n=== T7: M0 reads from S0 and S1 concurrently ===");
    begin
      int l0 = m0_rlast;
      fork
        ar(m0, 4'd3, 32'h0000_8000, 8'd3);
        begin tick(2); ar(m0, 4'd4, 32'h1000_8000, 8'd3); end
      join
      for (int i = 0; i < 1500 && m0_rlast < l0+2; i++) tick();
      chk("T7", (m0_rlast == l0+2),
          $sformatf("only %0d/2 bursts returned -- return-mux starvation",
                    m0_rlast-l0));
    end
    tick(20);

    $display("\n=== T8: M0 and M1 both read S0, responses interleave ===");
    begin
      int l0 = m0_rlast, l1 = m1_rlast;
      fork
        ar(m0, 4'd6, 32'h0000_9000, 8'd3);
        begin tick(1); ar(m1, 4'd8, 32'h0000_A000, 8'd3); end
      join
      for (int i = 0; i < 2000 && (m0_rlast < l0+1 || m1_rlast < l1+1); i++) tick();
      chk("T8", (m0_rlast == l0+1 && m1_rlast == l1+1),
          $sformatf("M0 %0d/1, M1 %0d/1 -- a burst was lost or a port wedged",
                    m0_rlast-l0, m1_rlast-l1));
    end

    tick(20);
    $display("\n==================================");
    if (errors == 0) $display("ALL EXTENDED TESTS PASSED");
    else             $display("%0d TEST(S) FAILED", errors);
    $display("==================================");
    u_cov.cov_report();
    $finish;
  end

  initial begin
    #200000;
    $display("GLOBAL TIMEOUT -- m0_b=%0d m1_b=%0d m0_rlast=%0d m1_rlast=%0d",
             m0_b, m1_b, m0_rlast, m1_rlast);
    $finish;
  end
endmodule
