// functional coverage collector.
//
// Note: covergroups are unsupported in this simulator version, so the bins are
// counters. The bin LIST is the portable part: it transfers directly to real
// covergroups in XSim, which does support them. Only the syntax changes.
//
// Bound into the testbench, not the DUT, so it can be dropped without touching
// RTL. Call cov_report() at the end of a run.
module axi4_cov #(
  parameter string NAME = "run"
) (
  input logic aclk,
  input logic arst_n,

  input logic [2:0] p0_awp, p1_awp,
  input logic [2:0] p0_wp,  p1_wp,
  input logic [2:0] p0_ten, p1_ten,
  input logic       p0_gnt, p1_gnt,
  input logic [1:0] p0_dest, p1_dest,
  input logic       p0_full, p1_full,
  input logic       p0_cont, p1_cont,
  input logic       p0_close, p1_close,
  input logic       p0_cmt, p1_cmt,
  input logic       p0_throk, p1_throk,
  input logic       p0_admit, p1_admit,
  input logic       p0_rel, p1_rel,
  input logic [1:0] p0_awdest, p1_awdest,
  input logic       p0_awv, p1_awv,

  input logic [2:0] r0_arp, r1_arp,
  input logic       r0_full, r1_full,

  input logic [1:0] t0w_act, t1w_act, t0r_act, t1r_act,

  input logic [1:0] s0w_gnt, s1w_gnt, s0r_gnt, s1r_gnt,
  input logic       s0w_gv,  s1w_gv,  s0r_gv,  s1r_gv,

  input logic [2:0] b0_req, b1_req, r0_req, r1_req,
  input logic       r0_mid, r1_mid,

  input logic [1:0] sk_aw0, sk_w0, sk_ar0, sk_b0, sk_r0,

  input logic       aw_hs, ar_hs,
  input logic [7:0] aw_len, ar_len,
  input logic [1:0] aw_burst, ar_burst,
  input logic [2:0] aw_size, ar_size,
  input logic [1:0] aw_dest_pin, ar_dest_pin,

  input logic       dw0_busy, dr0_busy
);

  int b_tenure   [0:4];
  int b_awp      [0:4];
  int b_wp       [0:4];
  int b_arp      [0:4];
  int b_thr_wr   [0:2];
  int b_thr_rd   [0:2];
  int b_dest     [0:2];
  int b_switch   [0:2][0:2];
  int b_grant    [0:3];
  int b_mux_req  [0:7];
  int b_skid     [0:4][0:2];
  int b_burst    [0:3];
  int b_len      [0:3];
  int b_size     [0:2];
  int b_len_dest [0:3][0:2];
  int b_burst_dest[0:3][0:2];

  int e_close_adm;
  int e_committed;
  int e_contested;
  int e_full_block;
  int e_thr_block;
  int e_release;
  int e_handover_w;
  int e_handover_r;
  int e_both_gnt;
  int e_decerr_wr;
  int e_decerr_rd;
  int e_midburst;
  int e_all3_mux;
  int e_rst_busy;

  logic [1:0] prev_s0w, prev_s0r;
  int lc, sc;
  logic busy_d;
  logic rst_d;

  always_ff @(posedge aclk) begin
    rst_d  <= arst_n;
    busy_d <= (p0_awp != 0) || (p1_awp != 0) || (r0_arp != 0) || (r1_arp != 0);
    if (!arst_n) begin
      if (rst_d && busy_d) e_rst_busy++;
    end
    else begin
      b_tenure[p0_ten]++;  b_tenure[p1_ten]++;
      b_awp[p0_awp]++;     b_awp[p1_awp]++;
      b_wp[p0_wp]++;       b_wp[p1_wp]++;
      b_arp[r0_arp]++;     b_arp[r1_arp]++;
      b_thr_wr[t0w_act]++; b_thr_wr[t1w_act]++;
      b_thr_rd[t0r_act]++; b_thr_rd[t1r_act]++;

      b_dest[p0_dest]++;
      b_dest[p1_dest]++;
      if (p0_awv) b_switch[p0_dest][p0_awdest]++;
      if (p1_awv) b_switch[p1_dest][p1_awdest]++;

      b_grant[{p1_gnt, p0_gnt}]++;
      if (p0_gnt && p1_gnt) e_both_gnt++;

      b_mux_req[b0_req]++; b_mux_req[b1_req]++;
      b_mux_req[r0_req]++; b_mux_req[r1_req]++;
      if (b0_req == 3'b111 || b1_req == 3'b111 ||
          r0_req == 3'b111 || r1_req == 3'b111) e_all3_mux++;
      if (r0_mid || r1_mid) e_midburst++;

      b_skid[0][sk_aw0]++; b_skid[1][sk_w0]++; b_skid[2][sk_ar0]++;
      b_skid[3][sk_b0]++;  b_skid[4][sk_r0]++;

      if (p0_close || p1_close) e_close_adm++;
      if (p0_cmt   || p1_cmt)   e_committed++;
      if (p0_cont  || p1_cont)  e_contested++;
      if (p0_rel   || p1_rel)   e_release++;
      if ((p0_awv && p0_full) || (p1_awv && p1_full)) e_full_block++;
      if ((p0_awv && !p0_throk) || (p1_awv && !p1_throk)) e_thr_block++;
      if (dw0_busy) e_decerr_wr++;
      if (dr0_busy) e_decerr_rd++;

      if (s0w_gv && (s0w_gnt != prev_s0w) && prev_s0w != 2'b00) e_handover_w++;
      if (s0r_gv && (s0r_gnt != prev_s0r) && prev_s0r != 2'b00) e_handover_r++;
      prev_s0w <= s0w_gnt;
      prev_s0r <= s0r_gnt;

      if (aw_hs) begin
        lc = (aw_len == 0) ? 0 : (aw_len < 15) ? 1 : (aw_len < 63) ? 2 : 3;
        sc = (aw_size > 2) ? 2 : aw_size;
        b_burst[aw_burst]++;
        b_len[lc]++;
        b_size[sc]++;
        b_len_dest[lc][aw_dest_pin]++;
        b_burst_dest[aw_burst][aw_dest_pin]++;
      end
      if (ar_hs) begin
        lc = (ar_len == 0) ? 0 : (ar_len < 15) ? 1 : (ar_len < 63) ? 2 : 3;
        sc = (ar_size > 2) ? 2 : ar_size;
        b_burst[ar_burst]++;
        b_len[lc]++;
        b_size[sc]++;
        b_len_dest[lc][ar_dest_pin]++;
        b_burst_dest[ar_burst][ar_dest_pin]++;
      end
    end
  end

  int hit, tot;

  function automatic void one(string label, int count);
    tot++;
    if (count > 0) begin hit++; $display("    %-38s %8d", label, count); end
    else                       $display("    %-38s %8s   <-- UNHIT", label, "0");
  endfunction

  task automatic cov_report();
    string dn [3] = '{"S0", "S1", "DECERR"};
    string bn [4] = '{"FIXED", "INCR", "WRAP", "resv"};
    string sn [5] = '{"m0 AW", "m0 W", "m0 AR", "s0 B", "s0 R"};
    string st [3] = '{"EMPTY", "ONE", "FULL"};
    hit = 0; tot = 0;
    $display("\n================ FUNCTIONAL COVERAGE (%s) ================", NAME);

    $display("\n  tenure_cnt  (close_admission needs >= %0d)", 4);
    for (int i=0;i<=4;i++) one($sformatf("tenure_cnt == %0d", i), b_tenure[i]);

    $display("\n  outstanding counters");
    for (int i=0;i<=4;i++) one($sformatf("aw_pending == %0d", i), b_awp[i]);
    for (int i=0;i<=4;i++) one($sformatf("w_pending  == %0d", i), b_wp[i]);
    for (int i=0;i<=4;i++) one($sformatf("ar_pending == %0d", i), b_arp[i]);

    $display("\n  thread tracker occupancy");
    for (int i=0;i<=2;i++) one($sformatf("wr tracker active == %0d", i), b_thr_wr[i]);
    for (int i=0;i<=2;i++) one($sformatf("rd tracker active == %0d", i), b_thr_rd[i]);

    $display("\n  grant state");
    for (int i=0;i<=2;i++) one($sformatf("mw_dest == %s", dn[i]), b_dest[i]);
    one("neither master granted",  b_grant[0]);
    one("M0 granted only",         b_grant[1]);
    one("M1 granted only",         b_grant[2]);
    one("both masters granted",    b_grant[3]);

    $display("\n  destination switch matrix (held -> next AW)");
    for (int a=0;a<=2;a++) for (int b=0;b<=2;b++)
      one($sformatf("%s -> %s", dn[a], dn[b]), b_switch[a][b]);

    $display("\n  response mux request vectors {DE,S1,S0}");
    for (int i=0;i<8;i++) begin
      if (i == 7) $display("    %-38s %8s", "req == 3'b111",
                           "n/a  (needs 3 IDs, NUM_THREADS=2)");
      else one($sformatf("req == 3'b%03b", i), b_mux_req[i]);
    end

    $display("\n  skid buffer states");
    for (int s=0;s<5;s++) for (int v=0;v<3;v++)
      one($sformatf("%s %s", sn[s], st[v]), b_skid[s][v]);

    $display("\n  burst attributes");
    for (int i=0;i<3;i++) one($sformatf("AxBURST %s", bn[i]), b_burst[i]);
    one("len 1 beat",        b_len[0]);
    one("len 2-15 beats",    b_len[1]);
    one("len 16-63 beats",   b_len[2]);
    one("len 64-256 beats",  b_len[3]);
    one("AxSIZE 1 byte",     b_size[0]);
    one("AxSIZE 2 bytes",    b_size[1]);
    one("AxSIZE 4 bytes",    b_size[2]);

    $display("\n  length x destination");
    for (int l=0;l<4;l++) for (int d=0;d<3;d++)
      one($sformatf("len[%0d] x %s", l, dn[d]), b_len_dest[l][d]);

    $display("\n  burst type x destination");
    for (int b=0;b<3;b++) for (int d=0;d<3;d++)
      one($sformatf("%s x %s", bn[b], dn[d]), b_burst_dest[b][d]);

    $display("\n  mechanism events");
    one("close_admission asserted", e_close_adm);
    one("aw_committed asserted",    e_committed);
    one("contested asserted",       e_contested);
    one("mw_release fired",         e_release);
    one("AW blocked by mw_full",    e_full_block);
    one("AW blocked by thr_ok",     e_thr_block);
    one("write grant handover",     e_handover_w);
    one("read grant handover",      e_handover_r);
    one("both masters granted",     e_both_gnt);
    one("DECERR write busy",        e_decerr_wr);
    one("DECERR read busy",         e_decerr_rd);
    one("R mux mid-burst",          e_midburst);
    $display("    %-38s %8s", "all 3 sources at one mux",
             "n/a  (see req == 3'b111)");
    one("reset with work in flight",e_rst_busy);

    $display("\n  ---------------------------------------------------");
    $display("  COVERAGE: %0d / %0d bins hit  (%0d%%)", hit, tot, (100*hit)/tot);
    $display("  ===================================================\n");
  endtask

endmodule
