// scoreboard. Everything before this checked that *a* response
// arrived; this checks that the *right* response arrived, with the right data,
// in the right order.
//
// Slaves are memory-backed, so a read of an address returns what was written
// there and the data path is verified end to end rather than just the handshake.
//
// Checks per transaction:
//   - exactly one B per write, correct BID, correct BRESP
//   - exactly ARLEN+1 R beats per read, correct RID, RRESP, RLAST placement
//   - read data equals what was written to that address
//   - same-ID responses arrive in issue order
//   - no unexpected or duplicate responses
//   - nothing outstanding when the test ends
`timescale 1ns/1ps

module tb_score;
  import axi4_pkg::*;

  logic aclk = 0, arst_n = 0;
  always #5 aclk = ~aclk;

  axi4_if #(.ID_W(ID_WIDTH)) m0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(ID_WIDTH)) m1 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s1 (.aclk(aclk), .arst_n(arst_n));

  axi4_xbar_top dut (.aclk(aclk), .arst_n(arst_n),
                     .m0(m0), .m1(m1), .s0(s0), .s1(s1));

  axi4_cov #(.NAME("tb_score")) u_cov (
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
    $display("  [%0t] SCOREBOARD ERROR: %s", $time, s); errors++;
  endtask

  logic [31:0] mem0 [logic [31:0]];
  logic [31:0] mem1 [logic [31:0]];

  int s0_aw_out=0, s0_b_n=0, s0_ar_out=0;
  int s1_aw_out=0, s1_b_n=0, s1_ar_out=0;
  logic [M_ID_W-1:0] s0_awq[$], s0_bq[$], s0_arq[$];
  logic [M_ID_W-1:0] s1_awq[$], s1_bq[$], s1_arq[$];
  logic [31:0] s0_awaq[$], s0_araq[$], s1_awaq[$], s1_araq[$];
  logic [7:0]  s0_arlq[$], s1_arlq[$];
  logic [2:0]  s0_arsq[$], s1_arsq[$];
  logic [31:0] s0_wa=0, s1_wa=0;
  logic [2:0]  s0_ws=0, s1_ws=0;
  logic [31:0] s0_ra=0, s1_ra=0;
  logic [2:0]  s0_rs=0, s1_rs=0;
  logic [7:0]  s0_rl=0, s1_rl=0;
  int s0_r_hold = 0;
  logic        s0_rdone, s1_rdone;
  logic s0_wstall=0, s1_wstall=0;
  bit bp_on = 0;
  int s0_b_hold = 0;

  always_ff @(posedge aclk) begin
    s0_wstall <= bp_on && ($urandom_range(0,3)==0);
    s1_wstall <= bp_on && ($urandom_range(0,3)==0);
  end

  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s0.awready <= 1'b0; else s0.awready <= s0.awvalid && !s0.awready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s1.awready <= 1'b0; else s1.awready <= s1.awvalid && !s1.awready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s0.arready <= 1'b0; else s0.arready <= s0.arvalid && !s0.arready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s1.arready <= 1'b0; else s1.arready <= s1.arvalid && !s1.arready;

  assign s0.wready = arst_n && (s0_aw_out > 0) && !s0_wstall;
  assign s1.wready = arst_n && (s1_aw_out > 0) && !s1_wstall;

  assign s0_rdone = arst_n && s0.rvalid && s0.rready && (s0_rl == 0);
  assign s1_rdone = arst_n && s1.rvalid && s1.rready && (s1_rl == 0);

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s0_aw_out<=0; s0_b_n<=0; s0_ar_out<=0; s0_wa<=0; s0_ws<=0;
      s0_awq.delete(); s0_bq.delete(); s0_arq.delete();
      s0_awaq.delete(); s0_araq.delete(); s0_arlq.delete(); s0_arsq.delete();
    end
    else begin
      automatic int ad=0, bd=0, rd=0;
      if (s0.awvalid && s0.awready) begin
        s0_awq.push_back(s0.awid); s0_awaq.push_back(s0.awaddr); ad++;
        if (s0_aw_out == 0) begin s0_wa <= s0.awaddr; s0_ws <= s0.awsize; end
      end
      if (s0.wvalid && s0.wready) begin
        mem0[s0_wa] <= s0.wdata;
        s0_wa <= s0_wa + (32'd1 << s0_ws);
        if (s0.wlast) begin
          s0_bq.push_back(s0_awq.pop_front());
          void'(s0_awaq.pop_front());
          ad--; bd++;
          if (s0_awaq.size() > 0) s0_wa <= s0_awaq[0];
        end
      end
      if (s0.bvalid && s0.bready) begin void'(s0_bq.pop_front()); bd--; end
      s0_aw_out <= s0_aw_out + ad;  s0_b_n <= s0_b_n + bd;

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
      s1_awq.delete(); s1_bq.delete(); s1_arq.delete();
      s1_awaq.delete(); s1_araq.delete(); s1_arlq.delete(); s1_arsq.delete();
    end
    else begin
      automatic int ad=0, bd=0, rd=0;
      if (s1.awvalid && s1.awready) begin
        s1_awq.push_back(s1.awid); s1_awaq.push_back(s1.awaddr); ad++;
        if (s1_aw_out == 0) begin s1_wa <= s1.awaddr; s1_ws <= s1.awsize; end
      end
      if (s1.wvalid && s1.wready) begin
        mem1[s1_wa] <= s1.wdata;
        s1_wa <= s1_wa + (32'd1 << s1_ws);
        if (s1.wlast) begin
          s1_bq.push_back(s1_awq.pop_front());
          void'(s1_awaq.pop_front());
          ad--; bd++;
          if (s1_awaq.size() > 0) s1_wa <= s1_awaq[0];
        end
      end
      if (s1.bvalid && s1.bready) begin void'(s1_bq.pop_front()); bd--; end
      s1_aw_out <= s1_aw_out + ad;  s1_b_n <= s1_b_n + bd;

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

  always_comb begin
    s0.bvalid = arst_n && (s0_b_n > 0) && (s0_b_hold == 0);
    s0.bid = s0.bvalid ? s0_bq[0] : '0;  s0.bresp = 2'b00;
    s1.bvalid = arst_n && (s1_b_n > 0);
    s1.bid = s1.bvalid ? s1_bq[0] : '0;  s1.bresp = 2'b00;
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s0.rvalid<=0; s0.rlast<=0; s0.rid<='0; s0.rdata<='0; s0.rresp<=0;
      s0_rl<=0; s0_ra<=0; s0_rs<=0;
    end
    else if (s0.rvalid && s0.rready) begin
      if (s0_rl != 0) begin
        s0_rl <= s0_rl - 1;
        s0_ra <= s0_ra + (32'd1 << s0_rs);
        s0.rdata <= mem0.exists(s0_ra + (32'd1 << s0_rs))
                    ? mem0[s0_ra + (32'd1 << s0_rs)] : 32'hDEAD_0000;
        s0.rlast <= (s0_rl == 1);
      end
      else s0.rvalid <= 1'b0;
    end
    else if (!s0.rvalid && s0_ar_out > 0 && s0_r_hold == 0) begin
      s0.rvalid <= 1'b1;  s0.rid <= s0_arq[0];
      s0_rl <= s0_arlq[0]; s0_ra <= s0_araq[0]; s0_rs <= s0_arsq[0];
      s0.rlast <= (s0_arlq[0] == 0);
      s0.rdata <= mem0.exists(s0_araq[0]) ? mem0[s0_araq[0]] : 32'hDEAD_0000;
    end
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s1.rvalid<=0; s1.rlast<=0; s1.rid<='0; s1.rdata<='0; s1.rresp<=0;
      s1_rl<=0; s1_ra<=0; s1_rs<=0;
    end
    else if (s1.rvalid && s1.rready) begin
      if (s1_rl != 0) begin
        s1_rl <= s1_rl - 1;
        s1_ra <= s1_ra + (32'd1 << s1_rs);
        s1.rdata <= mem1.exists(s1_ra + (32'd1 << s1_rs))
                    ? mem1[s1_ra + (32'd1 << s1_rs)] : 32'hDEAD_0000;
        s1.rlast <= (s1_rl == 1);
      end
      else s1.rvalid <= 1'b0;
    end
    else if (!s1.rvalid && s1_ar_out > 0) begin
      s1.rvalid <= 1'b1;  s1.rid <= s1_arq[0];
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
    int          issued_at;
  } txn_t;

  txn_t wr_exp [2][16][$];
  txn_t rd_exp [2][16][$];
  int   wr_out = 0, rd_out = 0;
  int   wr_done = 0, rd_done = 0;

  int      r_beat [2][16];
  logic [31:0] r_addr [2][16];

  function automatic void expect_write(int m, logic [3:0] id, logic [31:0] addr,
                                       logic [7:0] len, logic [2:0] size,
                                       logic [1:0] resp);
    txn_t t;
    t.id=id; t.addr=addr; t.len=len; t.size=size; t.exp_resp=resp;
    t.issued_at=$time;
    wr_exp[m][id].push_back(t);
    wr_out++;
  endfunction

  function automatic void expect_read(int m, logic [3:0] id, logic [31:0] addr,
                                      logic [7:0] len, logic [2:0] size,
                                      logic [1:0] resp);
    txn_t t;
    t.id=id; t.addr=addr; t.len=len; t.size=size; t.exp_resp=resp;
    t.issued_at=$time;
    rd_exp[m][id].push_back(t);
    rd_out++;
  endfunction

  task automatic check_b(int m, logic [3:0] bid, logic [1:0] bresp);
    txn_t t;
    if (wr_exp[m][bid].size() == 0) begin
      fail($sformatf("M%0d: unexpected B, id=%0d (nothing outstanding for that ID)",
                     m, bid));
      return;
    end
    t = wr_exp[m][bid].pop_front();
    if (bresp !== t.exp_resp)
      fail($sformatf("M%0d id=%0d: BRESP=%b, expected %b", m, bid, bresp, t.exp_resp));
    wr_out--; wr_done++;
  endtask

  task automatic check_r(int m, logic [3:0] rid, logic [31:0] rdata,
                         logic [1:0] rresp, logic rlast);
    txn_t t;
    logic [31:0] exp_addr, exp_data;
    if (rd_exp[m][rid].size() == 0) begin
      fail($sformatf("M%0d: unexpected R beat, id=%0d", m, rid));
      return;
    end
    t = rd_exp[m][rid][0];

    if (rresp !== t.exp_resp)
      fail($sformatf("M%0d id=%0d beat %0d: RRESP=%b, expected %b",
                     m, rid, r_beat[m][rid], rresp, t.exp_resp));

    if (t.exp_resp == 2'b00) begin
      exp_addr = t.addr + (r_beat[m][rid] << t.size);
      exp_data = (exp_addr[31:28] == 4'h0)
               ? (mem0.exists(exp_addr) ? mem0[exp_addr] : 32'hDEAD_0000)
               : (mem1.exists(exp_addr) ? mem1[exp_addr] : 32'hDEAD_0000);
      if (rdata !== exp_data)
        fail($sformatf("M%0d id=%0d beat %0d addr=%h: RDATA=%h, expected %h",
                       m, rid, r_beat[m][rid], exp_addr, rdata, exp_data));
    end

    if (rlast !== (r_beat[m][rid] == t.len))
      fail($sformatf("M%0d id=%0d: RLAST=%b on beat %0d, ARLEN implies last is beat %0d",
                     m, rid, rlast, r_beat[m][rid], t.len));

    if (rlast) begin
      void'(rd_exp[m][rid].pop_front());
      r_beat[m][rid] = 0;
      rd_out--; rd_done++;
    end
    else r_beat[m][rid] = r_beat[m][rid] + 1;
  endtask

  always_ff @(posedge aclk) if (arst_n) begin
    if (m0.bvalid && m0.bready) check_b(0, m0.bid, m0.bresp);
    if (m1.bvalid && m1.bready) check_b(1, m1.bid, m1.bresp);
    if (m0.rvalid && m0.rready) check_r(0, m0.rid, m0.rdata, m0.rresp, m0.rlast);
    if (m1.rvalid && m1.rready) check_r(1, m1.rid, m1.rdata, m1.rresp, m1.rlast);
  end

  task automatic drain(string what, int max_cycles = 3000);
    for (int i = 0; i < max_cycles && (wr_out != 0 || rd_out != 0); i++) tick();
    if (wr_out != 0 || rd_out != 0)
      fail($sformatf("%s: %0d writes and %0d reads never completed",
                     what, wr_out, rd_out));
  endtask

  function automatic logic [1:0] resp_of(logic [31:0] addr);
    return (addr[31:28] inside {4'h0, 4'h1}) ? 2'b00 : 2'b11;
  endfunction

  task automatic aw(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int m,
                    logic [3:0] id, logic [31:0] addr, logic [7:0] len,
                    logic [2:0] size = 3'd2, logic [1:0] bt = 2'b01);
    @(negedge aclk);
    v.awid=id; v.awaddr=addr; v.awlen=len; v.awsize=size; v.awburst=bt;
    v.awvalid=1'b1;
    expect_write(m, id, addr, len, size, resp_of(addr));
    do @(posedge aclk); while (!v.awready);
    @(negedge aclk); v.awvalid=1'b0;
  endtask

  task automatic ar(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int m,
                    logic [3:0] id, logic [31:0] addr, logic [7:0] len,
                    logic [2:0] size = 3'd2, logic [1:0] bt = 2'b01);
    @(negedge aclk);
    v.arid=id; v.araddr=addr; v.arlen=len; v.arsize=size; v.arburst=bt;
    v.arvalid=1'b1;
    expect_read(m, id, addr, len, size, resp_of(addr));
    do @(posedge aclk); while (!v.arready);
    @(negedge aclk); v.arvalid=1'b0;
  endtask

  task automatic wr(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int beats,
                    logic [31:0] seed);
    for (int i = 0; i < beats; i++) begin
      @(negedge aclk);
      v.wdata = seed + i; v.wstrb='1; v.wlast=(i==beats-1); v.wvalid=1'b1;
      do @(posedge aclk); while (!v.wready);
    end
    @(negedge aclk); v.wvalid=1'b0; v.wlast=1'b0;
  endtask

  task automatic wburst(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int m,
                        logic [3:0] id, logic [31:0] addr, int beats,
                        logic [31:0] seed, logic [2:0] size = 3'd2,
                        logic [1:0] bt = 2'b01);
    fork
      aw(v, m, id, addr, beats-1, size, bt);
      wr(v, beats, seed);
    join
  endtask

  localparam logic [31:0] A_S0 = 32'h0000_1000;
  localparam logic [31:0] A_S1 = 32'h1000_1000;
  localparam logic [31:0] A_BAD = 32'hF000_0000;

  int seed_ctr = 0;
  function automatic logic [31:0] nseed();
    seed_ctr++;
    return 32'h1000_0000 * (seed_ctr % 8) + seed_ctr * 32'h0001_0000;
  endfunction

  initial begin
    m0.awvalid=0; m0.wvalid=0; m0.arvalid=0; m0.bready=1; m0.rready=1;
    m1.awvalid=0; m1.wvalid=0; m1.arvalid=0; m1.bready=1; m1.rready=1;
    m0.awid=0; m0.awaddr=0; m0.awlen=0; m0.awsize=0; m0.awburst=0;
    m0.wdata=0; m0.wstrb=0; m0.wlast=0;
    m0.arid=0; m0.araddr=0; m0.arlen=0; m0.arsize=0; m0.arburst=0;
    m1.awid=0; m1.awaddr=0; m1.awlen=0; m1.awsize=0; m1.awburst=0;
    m1.wdata=0; m1.wstrb=0; m1.wlast=0;
    m1.arid=0; m1.araddr=0; m1.arlen=0; m1.arsize=0; m1.arburst=0;
    for (int m=0;m<2;m++) for (int i=0;i<16;i++) begin
      r_beat[m][i]=0; r_addr[m][i]=0;
    end
    tick(5); arst_n = 1; tick(5);

    $display("\n=== S1: write then read back, data must match ===");
    wburst(m0, 0, 4'd1, A_S0, 4, 32'hAAAA_0000);
    drain("S1 write");
    ar(m0, 0, 4'd1, A_S0, 8'd3);
    drain("S1 read");
    $display("  S1 done (errors so far: %0d)", errors);

    $display("\n=== S2: both masters, both slaves, read-back checked ===");
    fork
      wburst(m0, 0, 4'd2, A_S0 + 32'h100, 4, 32'hBBBB_0000);
      wburst(m1, 1, 4'd3, A_S1 + 32'h100, 4, 32'hCCCC_0000);
    join
    drain("S2 writes");
    fork
      ar(m0, 0, 4'd2, A_S0 + 32'h100, 8'd3);
      ar(m1, 1, 4'd3, A_S1 + 32'h100, 8'd3);
    join
    drain("S2 reads");
    $display("  S2 done (errors so far: %0d)", errors);

    $display("\n=== S3: same ID pipelined -- responses must be in issue order ===");
    fork
      begin for (int i=0;i<4;i++) aw(m0, 0, 4'd4, A_S0 + 32'h200 + i*16, 8'd3); end
      begin for (int i=0;i<4;i++) wr(m0, 4, 32'hD000_0000 + i*32'h100);        end
    join
    drain("S3 writes");
    for (int i=0;i<4;i++) ar(m0, 0, 4'd4, A_S0 + 32'h200 + i*16, 8'd3);
    drain("S3 reads");
    $display("  S3 done (errors so far: %0d)", errors);

    $display("\n=== S4: DECERR responses checked for RESP and beat count ===");
    wburst(m0, 0, 4'd5, A_BAD, 4, 32'hEEEE_0000);
    drain("S4 decerr write");
    ar(m0, 0, 4'd6, A_BAD, 8'd3);
    drain("S4 decerr read");
    $display("  S4 done (errors so far: %0d)", errors);

    $display("\n=== S5: both masters contend on S0, backpressure on ===");
    bp_on = 1;
    fork
      begin for (int i=0;i<8;i++) aw(m0, 0, 4'd7, A_S0 + 32'h400 + i*16, 8'd3); end
      begin for (int i=0;i<8;i++) wr(m0, 4, 32'h7000_0000 + i*32'h100);         end
      begin for (int i=0;i<8;i++) aw(m1, 1, 4'd8, A_S0 + 32'h600 + i*16, 8'd3); end
      begin for (int i=0;i<8;i++) wr(m1, 4, 32'h8000_0000 + i*32'h100);         end
    join
    drain("S5 writes", 6000);
    fork
      begin for (int i=0;i<8;i++) ar(m0, 0, 4'd7, A_S0 + 32'h400 + i*16, 8'd3); end
      begin for (int i=0;i<8;i++) ar(m1, 1, 4'd8, A_S0 + 32'h600 + i*16, 8'd3); end
    join
    drain("S5 reads", 6000);
    $display("  S5 done (errors so far: %0d)", errors);

    $display("\n=== S6: mixed IDs, both directions, both slaves ===");
    fork
      begin
        for (int i=0;i<6;i++)
          aw(m0, 0, 4'd9 + (i%2), (i%2 ? A_S1 : A_S0) + 32'h800 + i*16, 8'd1);
      end
      begin for (int i=0;i<6;i++) wr(m0, 2, 32'h9000_0000 + i*32'h100); end
      begin
        for (int i=0;i<6;i++)
          ar(m1, 1, 4'd11 + (i%2), (i%2 ? A_S1 : A_S0) + 32'h100, 8'd1);
      end
    join
    drain("S6", 8000);
    $display("  S6 done (errors so far: %0d)", errors);

    $display("\n=== S7: back-to-back B for different masters at one slave ===");
    begin
      bp_on = 0;
      for (int rep = 0; rep < 6; rep++) begin
        @(negedge aclk); s0_b_hold = 1;
        fork
          wburst(m0, 0, 4'd1 + rep[3:0], A_S0 + 32'hA00 + rep*32, 2, 32'hA100_0000 + rep);
          begin tick(2);
            wburst(m1, 1, 4'd8 + rep[3:0], A_S0 + 32'hB00 + rep*32, 2, 32'hB100_0000 + rep);
          end
        join
        for (int i = 0; i < 300 && s0_b_n < 2; i++) tick();
        @(negedge aclk); s0_b_hold = 0;
        drain($sformatf("S7 rep %0d", rep), 1500);
      end
      $display("  S7 done (errors so far: %0d)", errors);
    end

    $display("\n=== S8: back-to-back R bursts for different masters at one slave ===");
    begin
      for (int rep = 0; rep < 6; rep++) begin
        @(negedge aclk); s0_r_hold = 1;
        fork
          ar(m0, 0, 4'd2 + rep[3:0], A_S0 + 32'hA00 + rep*32, 8'd1);
          begin tick(2); ar(m1, 1, 4'd9 + rep[3:0], A_S0 + 32'hB00 + rep*32, 8'd1); end
        join
        for (int i = 0; i < 300 && s0_ar_out < 2; i++) tick();
        @(negedge aclk); s0_r_hold = 0;
        drain($sformatf("S8 rep %0d", rep), 2000);
      end
      $display("  S8 done (errors so far: %0d)", errors);
    end

    $display("\n=== S9: WRAP / FIXED / narrow AxSIZE ===");
    begin
      wburst(m0, 0, 4'd1, 32'h0000_2000,  2, 32'h2000_0000, 3'd2, 2'b10);
      wburst(m0, 0, 4'd1, 32'h0000_2010,  4, 32'h2100_0000, 3'd2, 2'b10);
      wburst(m0, 0, 4'd1, 32'h0000_2040, 16, 32'h2200_0000, 3'd2, 2'b10);
      drain("S9 wrap writes", 3000);
      ar(m0, 0, 4'd2, 32'h0000_2000, 8'd1, 3'd2, 2'b10);
      ar(m0, 0, 4'd2, 32'h0000_2040, 8'd15, 3'd2, 2'b10);
      drain("S9 wrap reads", 3000);

      wburst(m1, 1, 4'd3, 32'h1000_3000, 4, 32'h3000_0000, 3'd2, 2'b00);
      drain("S9 fixed write", 2000);
      ar(m1, 1, 4'd3, 32'h1000_3000, 8'd3, 3'd2, 2'b00);
      drain("S9 fixed read", 2000);

      wburst(m0, 0, 4'd4, 32'h0000_4000, 4, 32'h4000_0000, 3'd0);
      wburst(m0, 0, 4'd4, 32'h0000_4100, 4, 32'h4100_0000, 3'd1);
      drain("S9 narrow writes", 3000);
      $display("  S9 done (errors so far: %0d)", errors);
    end

    $display("\n=== S10: 16 / 64 / 256-beat INCR ===");
    begin
      wburst(m0, 0, 4'd5, 32'h0000_5000,  16, 32'h5000_0000);
      drain("S10 16-beat", 4000);
      wburst(m0, 0, 4'd5, 32'h0000_5100,  64, 32'h5100_0000);
      drain("S10 64-beat", 8000);
      wburst(m0, 0, 4'd5, 32'h0000_5400, 256, 32'h5400_0000);
      drain("S10 256-beat write", 30000);
      ar(m0, 0, 4'd6, 32'h0000_5400, 8'd255);
      drain("S10 256-beat read", 30000);
      $display("  S10 done (errors so far: %0d)", errors);
    end

    $display("\n=== S11: single-beat bursts and DECERR variety ===");
    begin
      for (int i = 0; i < 6; i++)
        wburst(m0, 0, 4'd7, 32'h0000_6000 + i*4, 1, 32'h6000_0000 + i);
      drain("S11 single-beat writes", 3000);
      for (int i = 0; i < 6; i++) ar(m0, 0, 4'd7, 32'h0000_6000 + i*4, 8'd0);
      drain("S11 single-beat reads", 3000);
      wburst(m0, 0, 4'd8, A_BAD + 32'h100, 16, 32'h8000_0000);
      drain("S11 decerr long write", 4000);
      ar(m0, 0, 4'd9, A_BAD + 32'h200, 8'd15);
      drain("S11 decerr long read", 4000);
      $display("  S11 done (errors so far: %0d)", errors);
    end

    $display("\n=== S12: three distinct IDs -- tracker-full blocking ===");
    begin
      bp_on = 1;
      fork
        begin
          aw(m0, 0, 4'd10, A_S0 + 32'hC00, 8'd3);
          aw(m0, 0, 4'd11, A_S0 + 32'hC10, 8'd3);
          aw(m0, 0, 4'd12, A_S0 + 32'hC20, 8'd3);
          aw(m0, 0, 4'd13, A_S0 + 32'hC30, 8'd3);
        end
        begin for (int i=0;i<4;i++) wr(m0, 4, 32'hC000_0000 + i*32'h100); end
      join
      drain("S12", 6000);

      fork
        begin
          ar(m1, 1, 4'd10, A_S0 + 32'hC00, 8'd3);
          ar(m1, 1, 4'd11, A_S0 + 32'hC10, 8'd3);
          ar(m1, 1, 4'd12, A_S0 + 32'hC20, 8'd3);
          ar(m1, 1, 4'd13, A_S0 + 32'hC30, 8'd3);
        end
      join
      drain("S12 reads", 6000);
      $display("  S12 done (errors so far: %0d)", errors);
    end

    tick(50);
    $display("\n==================================");
    $display("  writes completed : %0d", wr_done);
    $display("  reads  completed : %0d", rd_done);
    $display("  still outstanding: %0d wr, %0d rd", wr_out, rd_out);
    if (errors == 0) $display("SCOREBOARD CLEAN -- all responses correct");
    else             $display("%0d SCOREBOARD ERROR(S)", errors);
    $display("==================================");
    u_cov.cov_report();
    $finish;
  end

  initial begin
    #3000000;
    $display("GLOBAL TIMEOUT -- outstanding: %0d wr, %0d rd", wr_out, rd_out);
    $finish;
  end
endmodule
