// constrained-random stimulus, scoreboard-checked, coverage-measured.
//
// The constraints matter more than the seed count. Defaults reach almost none
// of the interesting states:
//   - IDs must come from a SMALL pool, or a 2-entry tracker never fills
//   - slave latency must exceed master issue rate, or aw_pending never nears 4
//   - both masters must target one slave often, or contention never happens
//   - responses must sometimes be held so two land back to back
//   - DECERR must be frequent enough to hold the destination lock
//
// This simulator has no constraint solver, so the weighting is written by hand.
`timescale 1ns/1ps

module tb_rand;
  import axi4_pkg::*;

  logic aclk = 0, arst_n = 0;
  always #5 aclk = ~aclk;

  axi4_if #(.ID_W(ID_WIDTH)) m0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(ID_WIDTH)) m1 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s1 (.aclk(aclk), .arst_n(arst_n));

  axi4_xbar_top dut (.aclk(aclk), .arst_n(arst_n),
                     .m0(m0), .m1(m1), .s0(s0), .s1(s1));

  axi4_cov #(.NAME("tb_rand")) u_cov (
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
  task automatic fail(string s);
    if (errors < 20) $display("  [%0t] ERROR: %s", $time, s);
    errors++;
  endtask

  logic [31:0] mem0 [logic [31:0]];
  logic [31:0] mem1 [logic [31:0]];

  int s0_aw_out=0, s0_b_n=0, s0_ar_out=0, s1_aw_out=0, s1_b_n=0, s1_ar_out=0;
  logic [M_ID_W-1:0] s0_awq[$], s0_bq[$], s0_arq[$], s1_awq[$], s1_bq[$], s1_arq[$];
  logic [31:0] s0_awaq[$], s0_araq[$], s1_awaq[$], s1_araq[$];
  logic [7:0]  s0_arlq[$], s1_arlq[$];
  logic [2:0]  s0_awsq[$], s1_awsq[$];
  logic [2:0]  s0_arsq[$], s1_arsq[$];
  logic [31:0] s0_wa=0, s1_wa=0, s0_ra=0, s1_ra=0;
  logic [2:0]  s0_ws=0, s1_ws=0, s0_rs=0, s1_rs=0;
  logic [7:0]  s0_rl=0, s1_rl=0;
  logic s0_rdone, s1_rdone;
  logic s0_wst=0, s1_wst=0, s0_bh=0, s1_bh=0, s0_rh=0, s1_rh=0;

  always_ff @(posedge aclk) begin
    s0_wst <= ($urandom_range(0,3) == 0);
    s1_wst <= ($urandom_range(0,3) == 0);

    s0_bh  <= ($urandom_range(0,2) != 0);
    s1_bh  <= ($urandom_range(0,2) != 0);
    s0_rh  <= ($urandom_range(0,2) != 0);
    s1_rh  <= ($urandom_range(0,2) != 0);
  end

  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s0.awready <= 1'b0; else s0.awready <= s0.awvalid && !s0.awready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s1.awready <= 1'b0; else s1.awready <= s1.awvalid && !s1.awready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s0.arready <= 1'b0; else s0.arready <= s0.arvalid && !s0.arready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s1.arready <= 1'b0; else s1.arready <= s1.arvalid && !s1.arready;

  assign s0.wready = arst_n && (s0_aw_out > 0) && !s0_wst;
  assign s1.wready = arst_n && (s1_aw_out > 0) && !s1_wst;
  assign s0_rdone  = arst_n && s0.rvalid && s0.rready && (s0_rl == 0);
  assign s1_rdone  = arst_n && s1.rvalid && s1.rready && (s1_rl == 0);

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s0_aw_out<=0; s0_b_n<=0; s0_ar_out<=0; s0_wa<=0; s0_ws<=0;
      s0_awq.delete(); s0_bq.delete(); s0_arq.delete(); s0_awsq.delete();
      s0_awaq.delete(); s0_araq.delete(); s0_arlq.delete(); s0_arsq.delete();
    end else begin
      automatic int ad=0, bd=0, rd=0;
      if (s0.awvalid && s0.awready) begin
        s0_awq.push_back(s0.awid); s0_awaq.push_back(s0.awaddr);
        s0_awsq.push_back(s0.awsize); ad++;
        if (s0_aw_out == 0) begin s0_wa <= s0.awaddr; s0_ws <= s0.awsize; end
      end
      if (s0.wvalid && s0.wready) begin
        mem0[s0_wa] <= s0.wdata;
        s0_wa <= s0_wa + (32'd1 << s0_ws);
        if (s0.wlast) begin
          s0_bq.push_back(s0_awq.pop_front()); void'(s0_awaq.pop_front());
          void'(s0_awsq.pop_front());
          ad--; bd++;
          if (s0_awaq.size() > 0) begin
            s0_wa <= s0_awaq[0]; s0_ws <= s0_awsq[0];
          end
        end
      end
      if (s0.bvalid && s0.bready) begin void'(s0_bq.pop_front()); bd--; end
      s0_aw_out <= s0_aw_out + ad; s0_b_n <= s0_b_n + bd;
      if (s0.arvalid && s0.arready) begin
        s0_arq.push_back(s0.arid); s0_araq.push_back(s0.araddr);
        s0_arlq.push_back(s0.arlen); s0_arsq.push_back(s0.arsize); rd++;
      end
      if (s0_rdone) begin
        void'(s0_arq.pop_front()); void'(s0_araq.pop_front());
        void'(s0_arlq.pop_front()); void'(s0_arsq.pop_front()); rd--;
      end
      s0_ar_out <= s0_ar_out + rd;
    end
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s1_aw_out<=0; s1_b_n<=0; s1_ar_out<=0; s1_wa<=0; s1_ws<=0;
      s1_awq.delete(); s1_bq.delete(); s1_arq.delete(); s1_awsq.delete();
      s1_awaq.delete(); s1_araq.delete(); s1_arlq.delete(); s1_arsq.delete();
    end else begin
      automatic int ad=0, bd=0, rd=0;
      if (s1.awvalid && s1.awready) begin
        s1_awq.push_back(s1.awid); s1_awaq.push_back(s1.awaddr);
        s1_awsq.push_back(s1.awsize); ad++;
        if (s1_aw_out == 0) begin s1_wa <= s1.awaddr; s1_ws <= s1.awsize; end
      end
      if (s1.wvalid && s1.wready) begin
        mem1[s1_wa] <= s1.wdata;
        s1_wa <= s1_wa + (32'd1 << s1_ws);
        if (s1.wlast) begin
          s1_bq.push_back(s1_awq.pop_front()); void'(s1_awaq.pop_front());
          void'(s1_awsq.pop_front());
          ad--; bd++;
          if (s1_awaq.size() > 0) begin
            s1_wa <= s1_awaq[0]; s1_ws <= s1_awsq[0];
          end
        end
      end
      if (s1.bvalid && s1.bready) begin void'(s1_bq.pop_front()); bd--; end
      s1_aw_out <= s1_aw_out + ad; s1_b_n <= s1_b_n + bd;
      if (s1.arvalid && s1.arready) begin
        s1_arq.push_back(s1.arid); s1_araq.push_back(s1.araddr);
        s1_arlq.push_back(s1.arlen); s1_arsq.push_back(s1.arsize); rd++;
      end
      if (s1_rdone) begin
        void'(s1_arq.pop_front()); void'(s1_araq.pop_front());
        void'(s1_arlq.pop_front()); void'(s1_arsq.pop_front()); rd--;
      end
      s1_ar_out <= s1_ar_out + rd;
    end
  end

  logic s0_bv_r = 0, s1_bv_r = 0;
  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin s0_bv_r <= 0; s1_bv_r <= 0; end
    else begin
      if (s0.bvalid && s0.bready)            s0_bv_r <= 0;
      else if (!s0_bv_r && (s0_b_n > 0) && !s0_bh) s0_bv_r <= 1;
      if (s1.bvalid && s1.bready)            s1_bv_r <= 0;
      else if (!s1_bv_r && (s1_b_n > 0) && !s1_bh) s1_bv_r <= 1;
    end
  end

  always_comb begin
    s0.bvalid = arst_n && s0_bv_r && (s0_b_n > 0) && !hold_all;
    s0.bid = s0.bvalid ? s0_bq[0] : '0;  s0.bresp = 2'b00;
    s1.bvalid = arst_n && s1_bv_r && (s1_b_n > 0) && !hold_all;
    s1.bid = s1.bvalid ? s1_bq[0] : '0;  s1.bresp = 2'b00;
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s0.rvalid<=0; s0.rlast<=0; s0.rid<='0; s0.rdata<='0; s0.rresp<=0;
      s0_rl<=0; s0_ra<=0; s0_rs<=0;
    end else if (s0.rvalid && s0.rready) begin
      if (s0_rl != 0) begin
        s0_rl <= s0_rl - 1;
        s0_ra <= s0_ra + (32'd1 << s0_rs);
        s0.rdata <= mem0.exists(s0_ra + (32'd1 << s0_rs))
                    ? mem0[s0_ra + (32'd1 << s0_rs)] : 32'hDEAD_0000;
        s0.rlast <= (s0_rl == 1);
      end else s0.rvalid <= 1'b0;
    end else if (!s0.rvalid && s0_ar_out > 0 && !s0_rh && !hold_all) begin
      s0.rvalid <= 1'b1; s0.rid <= s0_arq[0];
      s0_rl <= s0_arlq[0]; s0_ra <= s0_araq[0]; s0_rs <= s0_arsq[0];
      s0.rlast <= (s0_arlq[0] == 0);
      s0.rdata <= mem0.exists(s0_araq[0]) ? mem0[s0_araq[0]] : 32'hDEAD_0000;
    end
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s1.rvalid<=0; s1.rlast<=0; s1.rid<='0; s1.rdata<='0; s1.rresp<=0;
      s1_rl<=0; s1_ra<=0; s1_rs<=0;
    end else if (s1.rvalid && s1.rready) begin
      if (s1_rl != 0) begin
        s1_rl <= s1_rl - 1;
        s1_ra <= s1_ra + (32'd1 << s1_rs);
        s1.rdata <= mem1.exists(s1_ra + (32'd1 << s1_rs))
                    ? mem1[s1_ra + (32'd1 << s1_rs)] : 32'hDEAD_0000;
        s1.rlast <= (s1_rl == 1);
      end else s1.rvalid <= 1'b0;
    end else if (!s1.rvalid && s1_ar_out > 0 && !s1_rh && !hold_all) begin
      s1.rvalid <= 1'b1; s1.rid <= s1_arq[0];
      s1_rl <= s1_arlq[0]; s1_ra <= s1_araq[0]; s1_rs <= s1_arsq[0];
      s1.rlast <= (s1_arlq[0] == 0);
      s1.rdata <= mem1.exists(s1_araq[0]) ? mem1[s1_araq[0]] : 32'hDEAD_0000;
    end
  end

  typedef struct {
    logic [3:0]  id;
    logic [31:0] addr;
    logic [7:0]  len;
    logic [2:0]  size;
    logic [1:0]  exp_resp;
    logic [1:0]  bt;
    int          issue_epoch;
    bit          poisoned;
  } txn_t;

  txn_t wr_exp [2][16][$];
  txn_t rd_exp [2][16][$];
  int wr_out=0, rd_out=0, wr_done=0, rd_done=0;
  int r_beat [2][16];
  int epoch = 0;
  int last_wr  [logic [31:0]];
  int inflight [logic [31:0]];
  int skipped_data = 0;

  function automatic void stamp(logic [31:0] a, logic [7:0] len, logic [2:0] sz);
    epoch++;
    for (int i = 0; i <= len; i++) begin
      logic [31:0] x = a + (i << sz);
      last_wr[x] = epoch;
      if (!inflight.exists(x)) inflight[x] = 0;
      inflight[x]++;
    end
  endfunction

  function automatic void unstamp(logic [31:0] a, logic [7:0] len, logic [2:0] sz);
    for (int i = 0; i <= len; i++) begin
      logic [31:0] x = a + (i << sz);
      if (inflight.exists(x)) begin
        inflight[x]--;
        if (inflight[x] <= 0) inflight.delete(x);
      end
    end
  endfunction

  function automatic bit any_inflight(logic [31:0] a, logic [7:0] len, logic [2:0] sz);
    for (int i = 0; i <= len; i++)
      if (inflight.exists(a + (i << sz))) return 1;
    return 0;
  endfunction

  function automatic logic [1:0] resp_of(logic [31:0] a);
    return (a[31:28] inside {4'h0, 4'h1}) ? 2'b00 : 2'b11;
  endfunction

  task automatic check_b(int m, logic [3:0] bid, logic [1:0] bresp);
    txn_t t;
    if (wr_exp[m][bid].size() == 0) begin
      fail($sformatf("M%0d: unexpected B id=%0d", m, bid)); return;
    end
    t = wr_exp[m][bid].pop_front();
    if (bresp !== t.exp_resp)
      fail($sformatf("M%0d id=%0d: BRESP=%b expected %b", m, bid, bresp, t.exp_resp));
    if (t.exp_resp == 2'b00) unstamp(t.addr, t.len, t.size);
    wr_out--; wr_done++;
  endtask

  task automatic check_r(int m, logic [3:0] rid, logic [31:0] rdata,
                         logic [1:0] rresp, logic rlast);
    txn_t t;
    logic [31:0] ea, ed;
    if (rd_exp[m][rid].size() == 0) begin
      fail($sformatf("M%0d: unexpected R beat id=%0d", m, rid)); return;
    end
    t = rd_exp[m][rid][0];
    if (rresp !== t.exp_resp)
      fail($sformatf("M%0d id=%0d: RRESP=%b expected %b", m, rid, rresp, t.exp_resp));

    if (t.exp_resp == 2'b00 && t.bt == 2'b01) begin
      ea = t.addr + (r_beat[m][rid] << t.size);
      ed = (ea[31:28] == 4'h0) ? (mem0.exists(ea) ? mem0[ea] : 32'hDEAD_0000)
                               : (mem1.exists(ea) ? mem1[ea] : 32'hDEAD_0000);
      if (t.poisoned || inflight.exists(ea) ||
          (last_wr.exists(ea) && last_wr[ea] >= t.issue_epoch)) skipped_data++;
      else if (rdata !== ed)
        fail($sformatf("M%0d id=%0d beat %0d addr=%h: RDATA=%h expected %h",
                       m, rid, r_beat[m][rid], ea, rdata, ed));
    end
    if (rlast !== (r_beat[m][rid] == t.len))
      fail($sformatf("M%0d id=%0d: RLAST=%b on beat %0d, ARLEN says beat %0d",
                     m, rid, rlast, r_beat[m][rid], t.len));
    if (rlast) begin
      void'(rd_exp[m][rid].pop_front()); r_beat[m][rid] = 0; rd_out--; rd_done++;
    end else r_beat[m][rid] = r_beat[m][rid] + 1;
  endtask

  always_ff @(posedge aclk) if (arst_n) begin
    if (m0.bvalid && m0.bready) check_b(0, m0.bid, m0.bresp);
    if (m1.bvalid && m1.bready) check_b(1, m1.bid, m1.bresp);
    if (m0.rvalid && m0.rready) check_r(0, m0.rid, m0.rdata, m0.rresp, m0.rlast);
    if (m1.rvalid && m1.rready) check_r(1, m1.rid, m1.rdata, m1.rresp, m1.rlast);
  end

  function automatic logic [3:0] rand_id();
    return 4'(1 + $urandom_range(0,2));
  endfunction

  logic [31:0] last_base [2];
  int          have_last [2];

  function automatic logic [31:0] rand_addr(int bias_s0, logic [7:0] len,
                                            logic [2:0] sz, int m);
    int r, bytes, maxoff, off;
    logic [31:0] base;
    r = $urandom_range(0,99);

    if (have_last[m] && $urandom_range(0,99) < 35) base = last_base[m];
    else if (bias_s0)     base = 32'h0000_0000;
    else if (r < 40)      base = 32'h0000_0000;
    else if (r < 70)      base = 32'h1000_0000;
    else                  base = 32'hF000_0000;
    last_base[m] = base; have_last[m] = 1;
    bytes  = (len + 1) << sz;
    maxoff = 4096 - bytes;
    if (maxoff < 0) maxoff = 0;
    off = $urandom_range(0, maxoff);
    off = off & ~((1 << sz) - 1);
    return base + off;
  endfunction

  function automatic logic [1:0] rand_burst();
    int r = $urandom_range(0,99);
    if (r < 70) return 2'b01;
    else if (r < 90) return 2'b10;
    else return 2'b00;
  endfunction

  function automatic logic [7:0] rand_len(logic [1:0] bt);
    int r;
    if (bt == 2'b10) begin
      r = $urandom_range(0,3);
      return (r==0) ? 8'd1 : (r==1) ? 8'd3 : (r==2) ? 8'd7 : 8'd15;
    end
    else if (bt == 2'b00) return 8'($urandom_range(0,15));
    else begin
      r = $urandom_range(0,99);
      if (r < 30)      return 8'd0;
      else if (r < 60) return 8'($urandom_range(1,7));
      else if (r < 80) return 8'($urandom_range(8,31));
      else             return 8'($urandom_range(32,80));
    end
  endfunction

  function automatic logic [2:0] rand_size();
    int r = $urandom_range(0,99);
    return (r < 70) ? 3'd2 : (r < 85) ? 3'd1 : 3'd0;
  endfunction

  task automatic do_write(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int m, int bias);
    logic [3:0]  id;
    logic [1:0]  bt;
    logic [7:0]  len;
    logic [2:0]  sz;
    logic [31:0] addr;
    txn_t t;
    id = rand_id(); bt = rand_burst(); len = rand_len(bt); sz = rand_size();
    addr = rand_addr(bias, len, sz, m);
    t.id=id; t.addr=addr; t.len=len; t.size=sz; t.bt=bt; t.exp_resp=resp_of(addr);
    t.issue_epoch = epoch;
    t.poisoned = 0;
    wr_exp[m][id].push_back(t); wr_out++;

    if (t.exp_resp == 2'b00) stamp(addr, len, sz);
    @(negedge aclk);
    v.awid=id; v.awaddr=addr; v.awlen=len; v.awsize=sz; v.awburst=bt;
    v.awvalid=1'b1;
    do @(posedge aclk); while (!v.awready);
    @(negedge aclk); v.awvalid=1'b0;
    for (int i = 0; i <= len; i++) begin
      @(negedge aclk);
      v.wdata = 32'hC0DE_0000 + ((addr + (i << sz)) & 32'h0000_FFFF);
      v.wstrb='1; v.wlast=(i==len); v.wvalid=1'b1;
      do @(posedge aclk); while (!v.wready);
    end
    @(negedge aclk); v.wvalid=1'b0; v.wlast=1'b0;
  endtask

  task automatic do_read(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int m, int bias);
    logic [3:0]  id;
    logic [1:0]  bt;
    logic [7:0]  len;
    logic [2:0]  sz;
    logic [31:0] addr;
    txn_t t;
    id = rand_id(); bt = rand_burst(); len = rand_len(bt); sz = rand_size();
    addr = rand_addr(bias, len, sz, m);
    t.id=id; t.addr=addr; t.len=len; t.size=sz; t.bt=bt; t.exp_resp=resp_of(addr);
    t.issue_epoch = epoch;
    t.poisoned = any_inflight(addr, len, sz);
    rd_exp[m][id].push_back(t); rd_out++;
    @(negedge aclk);
    v.arid=id; v.araddr=addr; v.arlen=len; v.arsize=sz; v.arburst=bt;
    v.arvalid=1'b1;
    do @(posedge aclk); while (!v.arready);
    @(negedge aclk); v.arvalid=1'b0;
  endtask

  logic [31:0] wq_addr [2][$];
  logic [7:0]  wq_len  [2][$];
  logic [2:0]  wq_sz   [2][$];
  int wq_n [2];

  task automatic issue_aw(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int m, int bias);
    logic [3:0]  id;  logic [1:0] bt;  logic [7:0] len;
    logic [2:0]  sz;  logic [31:0] addr;
    txn_t t;
    id = rand_id(); bt = rand_burst(); len = rand_len(bt); sz = rand_size();
    addr = rand_addr(bias, len, sz, m);
    t.id=id; t.addr=addr; t.len=len; t.size=sz; t.bt=bt; t.exp_resp=resp_of(addr);
    t.issue_epoch = epoch; t.poisoned = 0;
    wr_exp[m][id].push_back(t); wr_out++;
    if (t.exp_resp == 2'b00) stamp(addr, len, sz);
    wq_addr[m].push_back(addr); wq_len[m].push_back(len); wq_sz[m].push_back(sz);
    wq_n[m]++;
    @(negedge aclk);
    v.awid=id; v.awaddr=addr; v.awlen=len; v.awsize=sz; v.awburst=bt;
    v.awvalid=1'b1;
    do @(posedge aclk); while (!v.awready);
    @(negedge aclk); v.awvalid=1'b0;
  endtask

  task automatic drive_w(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int m);
    logic [31:0] a; logic [7:0] l; logic [2:0] z;
    a = wq_addr[m].pop_front(); l = wq_len[m].pop_front(); z = wq_sz[m].pop_front();
    wq_n[m]--;
    for (int i = 0; i <= l; i++) begin
      @(negedge aclk);
      v.wdata = 32'hC0DE_0000 + ((a + (i << z)) & 32'h0000_FFFF);
      v.wstrb='1; v.wlast=(i==l); v.wvalid=1'b1;
      do @(posedge aclk); while (!v.wready);
    end
    @(negedge aclk); v.wvalid=1'b0; v.wlast=1'b0;
  endtask

  bit hold_all = 0;
  bit bp_off   = 0;

  task automatic issue_aw_fixed(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int m,
                                logic [3:0] id, logic [31:0] addr,
                                logic [7:0] len, logic [2:0] sz, logic [1:0] bt);
    txn_t t;
    t.id=id; t.addr=addr; t.len=len; t.size=sz; t.bt=bt; t.exp_resp=resp_of(addr);
    t.issue_epoch = epoch; t.poisoned = 0;
    wr_exp[m][id].push_back(t); wr_out++;
    if (t.exp_resp == 2'b00) stamp(addr, len, sz);
    wq_addr[m].push_back(addr); wq_len[m].push_back(len); wq_sz[m].push_back(sz);
    wq_n[m]++;
    @(negedge aclk);
    v.awid=id; v.awaddr=addr; v.awlen=len; v.awsize=sz; v.awburst=bt;
    v.awvalid=1'b1;
    do @(posedge aclk); while (!v.awready);
    @(negedge aclk); v.awvalid=1'b0;
  endtask

  task automatic do_read_fixed(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int m,
                               logic [3:0] id, logic [31:0] addr, logic [7:0] len);
    txn_t t;
    t.id=id; t.addr=addr; t.len=len; t.size=3'd2; t.bt=2'b01;
    t.exp_resp=resp_of(addr); t.issue_epoch=epoch;
    t.poisoned = any_inflight(addr, len, 3'd2);
    rd_exp[m][id].push_back(t); rd_out++;
    @(negedge aclk);
    v.arid=id; v.araddr=addr; v.arlen=len; v.arsize=3'd2; v.arburst=2'b01;
    v.arvalid=1'b1;
    do @(posedge aclk); while (!v.arready);
    @(negedge aclk); v.arvalid=1'b0;
  endtask

  int N_TXN = 400;

  initial begin
    m0.awvalid=0; m0.wvalid=0; m0.arvalid=0; m0.bready=1; m0.rready=1;
    m1.awvalid=0; m1.wvalid=0; m1.arvalid=0; m1.bready=1; m1.rready=1;
    m0.awid=0; m0.awaddr=0; m0.awlen=0; m0.awsize=0; m0.awburst=0;
    m0.wdata=0; m0.wstrb=0; m0.wlast=0;
    m0.arid=0; m0.araddr=0; m0.arlen=0; m0.arsize=0; m0.arburst=0;
    m1.awid=0; m1.awaddr=0; m1.awlen=0; m1.awsize=0; m1.awburst=0;
    m1.wdata=0; m1.wstrb=0; m1.wlast=0;
    m1.arid=0; m1.araddr=0; m1.arlen=0; m1.arsize=0; m1.arburst=0;
    for (int m=0;m<2;m++) for (int i=0;i<16;i++) r_beat[m][i]=0;

    if (!$value$plusargs("ntxn=%d", N_TXN)) N_TXN = 400;
    tick(5); arst_n = 1; tick(5);
    $display("=== constrained random: %0d transactions per master ===", N_TXN); $fflush();

    fork

      begin
        for (int i = 0; i < N_TXN/2; i++) issue_aw(m0, 0, ($urandom_range(0,9) < 4));
      end
      begin
        for (int i = 0; i < N_TXN/2; i++) begin
          while (wq_n[0] == 0) tick();
          drive_w(m0, 0);
        end
      end
      begin
        for (int i = 0; i < N_TXN/2; i++) begin
          do_read(m0, 0, ($urandom_range(0,9) < 4));
          if ($urandom_range(0,4) == 0) tick($urandom_range(1,3));
        end
      end

      begin
        for (int i = 0; i < N_TXN/2; i++) issue_aw(m1, 1, ($urandom_range(0,9) < 6));
      end
      begin
        for (int i = 0; i < N_TXN/2; i++) begin
          while (wq_n[1] == 0) tick();
          drive_w(m1, 1);
        end
      end
      begin
        for (int i = 0; i < N_TXN/2; i++) begin
          do_read(m1, 1, ($urandom_range(0,9) < 6));
          if ($urandom_range(0,4) == 0) tick($urandom_range(1,3));
        end
      end

      begin
        while (!bp_off) begin
          @(negedge aclk);
          m0.bready = ($urandom_range(0,4) != 0);
          m1.bready = ($urandom_range(0,4) != 0);
          m0.rready = ($urandom_range(0,4) != 0);
          m1.rready = ($urandom_range(0,4) != 0);
        end
      end
    join_any

    bp_off = 1;
    tick(3);
    @(negedge aclk);
    m0.bready=1; m1.bready=1; m0.rready=1; m1.rready=1;
    for (int i = 0; i < 200000 && (wr_out != 0 || rd_out != 0); i++) tick();

    $display("=== D1: consecutive DECERR writes, then a switch ===");
    for (int rep = 0; rep < 4; rep++) begin
      issue_aw_fixed(m0, 0, 4'd1, 32'hF000_0000 + rep*64, 8'd1, 3'd2, 2'b01);
      drive_w(m0, 0);
      issue_aw_fixed(m0, 0, 4'd1, 32'hF000_0100 + rep*64, 8'd1, 3'd2, 2'b01);
      drive_w(m0, 0);
      issue_aw_fixed(m0, 0, 4'd1, 32'h0000_0900 + rep*64, 8'd1, 3'd2, 2'b01);
      drive_w(m0, 0);
      issue_aw_fixed(m0, 0, 4'd1, 32'h1000_0900 + rep*64, 8'd1, 3'd2, 2'b01);
      drive_w(m0, 0);
      for (int i = 0; i < 4000 && (wr_out != 0 || rd_out != 0); i++) tick();
    end

    $display("=== D2: S0 + S1 + DECERR all returning to M0 ===");
    for (int rep = 0; rep < 8; rep++) begin
      @(negedge aclk); hold_all = 1; m0.rready = 0;
      do_read_fixed(m0, 0, 4'd2, 32'h0000_0A00 + rep*64, 8'd3);
      do_read_fixed(m0, 0, 4'd3, 32'h1000_0A00 + rep*64, 8'd3);
      do_read_fixed(m0, 0, 4'd4, 32'hF000_0A00 + rep*64, 8'd3);
      for (int i = 0; i < 60; i++) tick();
      @(negedge aclk); hold_all = 0;
      for (int i = 0; i < 60; i++) tick();
      @(negedge aclk); m0.rready = 1;
      for (int i = 0; i < 6000 && rd_out != 0; i++) tick();
    end

    $display("=== D3: reset asserted with transactions outstanding ===");
    for (int rep = 0; rep < 2; rep++) begin
      hold_all = 1;
      issue_aw_fixed(m0, 0, 4'd5, 32'h0000_0B00, 8'd3, 3'd2, 2'b01);
      fork drive_w(m0, 0); join_none
      do_read_fixed(m1, 1, 4'd6, 32'h1000_0B00, 8'd3);
      for (int i = 0; i < 60; i++) tick();

      @(negedge aclk);
      m0.awvalid=0; m0.wvalid=0; m0.wlast=0; m0.arvalid=0;
      m1.awvalid=0; m1.wvalid=0; m1.wlast=0; m1.arvalid=0;
      arst_n = 0; tick(4); arst_n = 1; tick(10);

      for (int mm=0; mm<2; mm++) for (int ii=0; ii<16; ii++) begin
        wr_exp[mm][ii].delete(); rd_exp[mm][ii].delete(); r_beat[mm][ii]=0;
      end
      wr_out = 0; rd_out = 0; wq_addr[0].delete(); wq_len[0].delete();
      wq_sz[0].delete(); wq_n[0] = 0;
      hold_all = 0;
      tick(20);
    end

    @(negedge aclk);
    m0.bready=1; m1.bready=1; m0.rready=1; m1.rready=1;
    for (int i = 0; i < 200000 && (wr_out != 0 || rd_out != 0); i++) tick();
    if (wr_out != 0 || rd_out != 0)
      fail($sformatf("%0d writes and %0d reads never completed", wr_out, rd_out));

    tick(50);
    $display("\n==================================");
    $display("  writes completed : %0d", wr_done);
    $display("  reads  completed : %0d", rd_done);
    $display("  data checks skipped (write in flight to same address): %0d",
             skipped_data);
    if (errors == 0) $display("RANDOM RUN CLEAN");
    else             $display("%0d ERROR(S)", errors);
    $display("==================================");
    u_cov.cov_report();
    $finish;
  end

  initial begin
    #50000000;
    $display("GLOBAL TIMEOUT -- outstanding %0d wr %0d rd", wr_out, rd_out);
    u_cov.cov_report();
    $finish;
  end
endmodule
