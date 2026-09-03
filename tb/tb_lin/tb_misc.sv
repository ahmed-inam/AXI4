// the directed groups tb_smoke/tb_ext/tb_grant do not cover.
//
//   RESET        T19  master out of reset before the crossbar (srst_n window)
//                T20  reset asserted mid-burst
//                T21  reset asserted with a response in flight
//                T22  reset asserted mid-tenure, then normal traffic resumes
//
//   BURST TYPE   T23  WRAP write, lengths 2/4/8/16
//                T24  WRAP read
//                T25  FIXED write and read
//                T26  INCR 256 beats
//                T27  unaligned start address
//                T28  burst ending exactly on a 4KB boundary
//                T29  AxSIZE below the bus width
//
//   SIMULTANEITY T30  both masters switch destination in the same cycle
//                T31  all three sources request one response mux at once
//                T32  completion and allocation of the same ID in one cycle
//                T33  zero-idle back-to-back writes
//                T34  zero-idle back-to-back reads
`timescale 1ns/1ps

module tb_misc;
  import axi4_pkg::*;

  logic aclk = 0, arst_n = 0;
  always #5 aclk = ~aclk;

  axi4_if #(.ID_W(ID_WIDTH)) m0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(ID_WIDTH)) m1 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s0 (.aclk(aclk), .arst_n(arst_n));
  axi4_if #(.ID_W(M_ID_W))   s1 (.aclk(aclk), .arst_n(arst_n));

  axi4_xbar_top dut (.aclk(aclk), .arst_n(arst_n),
                     .m0(m0), .m1(m1), .s0(s0), .s1(s1));

  int errors = 0;
  task automatic tick(int n = 1); repeat (n) @(posedge aclk); endtask
  task automatic chk(string name, bit cond, string msg);
    if (cond) $display("  %s PASS", name);
    else begin $display("  %s FAIL: %s", name, msg); errors++; end
  endtask

  int s0_aw_out=0, s0_b_n=0, s0_ar_out=0, s1_aw_out=0, s1_b_n=0, s1_ar_out=0;
  logic [M_ID_W-1:0] s0_awq[$], s0_bq[$], s0_arq[$], s1_awq[$], s1_bq[$], s1_arq[$];
  logic [7:0] s0_arlenq[$], s1_arlenq[$];
  logic [7:0] s0_r_left=0, s1_r_left=0;
  int s0_gap=0;
  logic s0_r_done, s1_r_done;

  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s0.awready <= 1'b0; else s0.awready <= s0.awvalid && !s0.awready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s1.awready <= 1'b0; else s1.awready <= s1.awvalid && !s1.awready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s0.arready <= 1'b0; else s0.arready <= s0.arvalid && !s0.arready;
  always_ff @(posedge aclk or negedge arst_n)
    if (!arst_n) s1.arready <= 1'b0; else s1.arready <= s1.arvalid && !s1.arready;

  assign s0.wready = arst_n && (s0_aw_out > 0);
  assign s1.wready = arst_n && (s1_aw_out > 0);

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s0_aw_out <= 0; s0_b_n <= 0; s0_ar_out <= 0;
      s1_aw_out <= 0; s1_b_n <= 0; s1_ar_out <= 0;
      s0_awq.delete(); s0_bq.delete(); s0_arq.delete(); s0_arlenq.delete();
      s1_awq.delete(); s1_bq.delete(); s1_arq.delete(); s1_arlenq.delete();
    end
    else begin
      automatic int a0=0,q0=0,a1=0,q1=0;
      if (s0.awvalid && s0.awready) begin s0_awq.push_back(s0.awid); a0++; end
      if (s0.wvalid && s0.wready && s0.wlast) begin
        s0_bq.push_back(s0_awq.pop_front()); a0--; q0++; end
      if (s0.bvalid && s0.bready) begin void'(s0_bq.pop_front()); q0--; end
      s0_aw_out <= s0_aw_out + a0; s0_b_n <= s0_b_n + q0;
      begin
        automatic int r0 = 0;
        if (s0.arvalid && s0.arready) begin
          s0_arq.push_back(s0.arid); s0_arlenq.push_back(s0.arlen); r0++;
        end
        if (s0_r_done) begin
          void'(s0_arq.pop_front()); void'(s0_arlenq.pop_front()); r0--;
        end
        s0_ar_out <= s0_ar_out + r0;
      end

      if (s1.awvalid && s1.awready) begin s1_awq.push_back(s1.awid); a1++; end
      if (s1.wvalid && s1.wready && s1.wlast) begin
        s1_bq.push_back(s1_awq.pop_front()); a1--; q1++; end
      if (s1.bvalid && s1.bready) begin void'(s1_bq.pop_front()); q1--; end
      s1_aw_out <= s1_aw_out + a1; s1_b_n <= s1_b_n + q1;
      begin
        automatic int r1 = 0;
        if (s1.arvalid && s1.arready) begin
          s1_arq.push_back(s1.arid); s1_arlenq.push_back(s1.arlen); r1++;
        end
        if (s1_r_done) begin
          void'(s1_arq.pop_front()); void'(s1_arlenq.pop_front()); r1--;
        end
        s1_ar_out <= s1_ar_out + r1;
      end
    end
  end

  assign s0_r_done = arst_n && s0.rvalid && s0.rready && (s0_r_left == 0);
  assign s1_r_done = arst_n && s1.rvalid && s1.rready && (s1_r_left == 0);

  always_comb begin
    s0.bvalid = arst_n && (s0_b_n > 0);
    s0.bid = s0.bvalid ? s0_bq[0] : '0;  s0.bresp = 2'b00;
    s1.bvalid = arst_n && (s1_b_n > 0);
    s1.bid = s1.bvalid ? s1_bq[0] : '0;  s1.bresp = 2'b00;
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s0.rvalid<=0; s0.rlast<=0; s0.rid<='0; s0.rdata<='0; s0.rresp<=0;
      s0_r_left<=0; s0_gap<=0;
    end
    else if (s0.rvalid && s0.rready) begin
      if (s0_r_left != 0) begin
        s0_r_left <= s0_r_left - 1;
        if ($urandom_range(0,2)==0) begin s0.rvalid<=0; s0_gap<=2; end
        else begin s0.rdata <= s0.rdata + 1; s0.rlast <= (s0_r_left==1); end
      end
      else begin
        s0.rvalid<=0; s0.rlast<=0;
      end
    end
    else if (s0_gap != 0) begin
      s0_gap <= s0_gap - 1;
      if (s0_gap == 1) begin
        s0.rvalid<=1; s0.rdata <= s0.rdata+1; s0.rlast <= (s0_r_left==0); end
    end
    else if (!s0.rvalid && s0_ar_out > 0) begin
      s0.rvalid<=1; s0.rid <= s0_arq[0]; s0_r_left <= s0_arlenq[0];
      s0.rlast <= (s0_arlenq[0]==0); s0.rdata <= 32'hA000_0000;
    end
  end

  always_ff @(posedge aclk or negedge arst_n) begin
    if (!arst_n) begin
      s1.rvalid<=0; s1.rlast<=0; s1.rid<='0; s1.rdata<='0; s1.rresp<=0; s1_r_left<=0;
    end
    else if (s1.rvalid && s1.rready) begin
      if (s1_r_left != 0) begin
        s1_r_left <= s1_r_left-1; s1.rdata <= s1.rdata+1;
        s1.rlast <= (s1_r_left==1);
      end
      else begin
        s1.rvalid<=0; s1.rlast<=0;
      end
    end
    else if (!s1.rvalid && s1_ar_out > 0) begin
      s1.rvalid<=1; s1.rid <= s1_arq[0]; s1_r_left <= s1_arlenq[0];
      s1.rlast <= (s1_arlenq[0]==0); s1.rdata <= 32'hB000_0000;
    end
  end

  int m0_b=0, m1_b=0, m0_r=0, m1_r=0, m0_rlast=0, m1_rlast=0;
  bit saw_alloc_and_cpl = 0;
  always_ff @(posedge aclk) if (arst_n)
    if (dut.g_mport[0].u_wr_thr.alloc && dut.g_mport[0].u_wr_thr.cpl_valid &&
        (dut.g_mport[0].u_wr_thr.q_id == dut.g_mport[0].u_wr_thr.cpl_id))
      saw_alloc_and_cpl <= 1;
  logic [3:0] m0_last_bid, m0_last_rid;
  always_ff @(posedge aclk) if (arst_n) begin
    if (m0.bvalid && m0.bready) begin m0_b<=m0_b+1; m0_last_bid<=m0.bid; end
    if (m1.bvalid && m1.bready) m1_b<=m1_b+1;
    if (m0.rvalid && m0.rready) begin
      m0_r<=m0_r+1; m0_last_rid<=m0.rid; if (m0.rlast) m0_rlast<=m0_rlast+1; end
    if (m1.rvalid && m1.rready) begin
      m1_r<=m1_r+1; if (m1.rlast) m1_rlast<=m1_rlast+1; end
  end

  task automatic aw(virtual axi4_if #(.ID_W(ID_WIDTH)) v, logic [3:0] id,
                    logic [31:0] addr, logic [7:0] len,
                    logic [2:0] size = 3'd2, logic [1:0] bt = 2'b01);
    @(negedge aclk);
    v.awid=id; v.awaddr=addr; v.awlen=len; v.awsize=size; v.awburst=bt;
    v.awvalid=1'b1;
    do @(posedge aclk); while (!v.awready);
    @(negedge aclk); v.awvalid=1'b0;
  endtask

  task automatic ar(virtual axi4_if #(.ID_W(ID_WIDTH)) v, logic [3:0] id,
                    logic [31:0] addr, logic [7:0] len,
                    logic [2:0] size = 3'd2, logic [1:0] bt = 2'b01);
    @(negedge aclk);
    v.arid=id; v.araddr=addr; v.arlen=len; v.arsize=size; v.arburst=bt;
    v.arvalid=1'b1;
    do @(posedge aclk); while (!v.arready);
    @(negedge aclk); v.arvalid=1'b0;
  endtask

  task automatic wr(virtual axi4_if #(.ID_W(ID_WIDTH)) v, int beats);
    for (int i = 0; i < beats; i++) begin
      @(negedge aclk);
      v.wdata=32'hD000_0000+i; v.wstrb='1; v.wlast=(i==beats-1); v.wvalid=1'b1;
      do @(posedge aclk); while (!v.wready);
    end
    @(negedge aclk); v.wvalid=1'b0; v.wlast=1'b0;
  endtask

  task automatic burst(virtual axi4_if #(.ID_W(ID_WIDTH)) v, logic [3:0] id,
                       logic [31:0] addr, int beats,
                       logic [2:0] size = 3'd2, logic [1:0] bt = 2'b01);
    fork
      aw(v, id, addr, beats-1, size, bt);
      wr(v, beats);
    join
  endtask

  task automatic quiesce();
    @(negedge aclk);
    m0.awvalid=0; m0.wvalid=0; m0.wlast=0; m0.arvalid=0;
    m1.awvalid=0; m1.wvalid=0; m1.wlast=0; m1.arvalid=0;
  endtask

  localparam logic [31:0] A_S0 = 32'h0000_1000;
  localparam logic [31:0] A_S1 = 32'h1000_1000;

  initial begin
    m0.awvalid=0; m0.wvalid=0; m0.arvalid=0; m0.bready=1; m0.rready=1;
    m1.awvalid=0; m1.wvalid=0; m1.arvalid=0; m1.bready=1; m1.rready=1;
    m0.awid=0; m0.awaddr=0; m0.awlen=0; m0.awsize=0; m0.awburst=0;
    m0.wdata=0; m0.wstrb=0; m0.wlast=0;
    m0.arid=0; m0.araddr=0; m0.arlen=0; m0.arsize=0; m0.arburst=0;
    m1.awid=0; m1.awaddr=0; m1.awlen=0; m1.awsize=0; m1.awburst=0;
    m1.wdata=0; m1.wstrb=0; m1.wlast=0;
    m1.arid=0; m1.araddr=0; m1.arlen=0; m1.arsize=0; m1.arburst=0;

    $display("\n=== T19: master awake before the crossbar (srst_n window) ===");

    begin
      bit early_ready = 0;
      arst_n = 1;

      for (int i = 0; i < 3; i++) begin
        @(posedge aclk);
        if (!dut.srst_n && (m0.awready || m0.wready || m0.arready))
          early_ready = 1;
      end
      chk("T19a", !early_ready,
          "master-facing READY was high while the fabric was still in reset");
      tick(5);
      burst(m0, 4'd1, A_S0, 2);
      for (int i = 0; i < 400 && m0_b < 1; i++) tick();
      chk("T19b", (m0_b == 1), "first transaction after reset release was lost");
    end
    tick(10);

    $display("\n=== T20: reset asserted mid-burst ===");
    begin
      int b0 = m0_b;
      fork
        begin aw(m0, 4'd2, A_S0, 8'd7); wr(m0, 8); end
        begin tick(6); end
      join_any
      disable fork;
      quiesce();
      arst_n = 0; tick(4); arst_n = 1;
      tick(10);
      chk("T20a", (dut.g_mport[0].u_wr_ctrl.aw_pending == 0 &&
                   dut.g_mport[0].u_wr_ctrl.w_pending  == 0 &&
                   dut.g_mport[0].u_wr_ctrl.mw_grant   == 1'b0),
          $sformatf("state not cleared: awp=%0d wp=%0d grant=%b",
                    dut.g_mport[0].u_wr_ctrl.aw_pending,
                    dut.g_mport[0].u_wr_ctrl.w_pending,
                    dut.g_mport[0].u_wr_ctrl.mw_grant));

      burst(m0, 4'd3, A_S0, 2);
      for (int i = 0; i < 400 && m0_b <= b0; i++) tick();
      chk("T20b", (m0_b > b0), "no traffic passes after a mid-burst reset");
    end
    tick(10);

    $display("\n=== T21: reset with a response in flight ===");
    begin
      int b0 = m0_b;
      fork
        burst(m0, 4'd4, A_S0, 2);
        begin for (int i = 0; i < 200 && s0_b_n == 0; i++) tick(); end
      join_any
      disable fork;
      quiesce();
      arst_n = 0; tick(4); arst_n = 1;
      tick(10);
      chk("T21a", (dut.g_mport[0].u_wr_ctrl.aw_pending == 0),
          "aw_pending survived reset");
      burst(m0, 4'd5, A_S0, 2);
      for (int i = 0; i < 400 && m0_b <= b0; i++) tick();
      chk("T21b", (m0_b > b0), "fabric dead after reset with a response in flight");
    end
    tick(10);

    $display("\n=== T22: reset mid-tenure under contention ===");
    begin
      int b0 = m0_b, b1 = m1_b;
      fork
        begin for (int i=0;i<6;i++) aw(m0, 4'd6, A_S0+i*64, 8'd1); end
        begin for (int i=0;i<6;i++) wr(m0, 2); end
        begin for (int i=0;i<6;i++) aw(m1, 4'd7, A_S0+i*64, 8'd1); end
        begin for (int i=0;i<6;i++) wr(m1, 2); end
        begin tick(40); end
      join_any
      disable fork;
      quiesce();
      arst_n = 0; tick(4); arst_n = 1;
      tick(10);
      chk("T22a", (dut.g_sport[0].u_swr.gnt_valid == 1'b0),
          "slave-port grant survived reset");
      fork burst(m0, 4'd8, A_S0, 2); burst(m1, 4'd9, A_S1, 2); join
      for (int i = 0; i < 600 && (m0_b <= b0 || m1_b <= b1); i++) tick();
      chk("T22b", (m0_b > b0 && m1_b > b1),
          "one or both ports dead after a mid-tenure reset");
    end
    tick(10);

    $display("\n=== T23: WRAP write, lengths 2/4/8/16 ===");
    begin
      int b0 = m0_b;

      burst(m0, 4'd1, 32'h0000_2000,  2, 3'd2, 2'b10);
      burst(m0, 4'd1, 32'h0000_2010,  4, 3'd2, 2'b10);
      burst(m0, 4'd1, 32'h0000_2020,  8, 3'd2, 2'b10);
      burst(m0, 4'd1, 32'h0000_2040, 16, 3'd2, 2'b10);
      for (int i = 0; i < 900 && m0_b < b0+4; i++) tick();
      chk("T23", (m0_b == b0+4), $sformatf("%0d/4 WRAP writes completed", m0_b-b0));
    end
    tick(10);

    $display("\n=== T24: WRAP read ===");
    begin
      int l0 = m0_rlast;
      ar(m0, 4'd2, 32'h0000_3000, 8'd3, 3'd2, 2'b10);
      for (int i = 0; i < 600 && m0_rlast < l0+1; i++) tick();
      chk("T24", (m0_rlast == l0+1), "WRAP read did not return RLAST");
    end
    tick(10);

    $display("\n=== T25: FIXED write and read ===");
    begin
      int b0 = m0_b, l0 = m0_rlast;
      burst(m0, 4'd3, 32'h0000_4000, 4, 3'd2, 2'b00);
      ar   (m0, 4'd3, 32'h0000_4000, 8'd3, 3'd2, 2'b00);
      for (int i = 0; i < 900 && (m0_b < b0+1 || m0_rlast < l0+1); i++) tick();
      chk("T25", (m0_b == b0+1 && m0_rlast == l0+1),
          $sformatf("FIXED: b=%0d rlast=%0d", m0_b-b0, m0_rlast-l0));
    end
    tick(10);

    $display("\n=== T26: INCR 256 beats ===");
    begin
      int b0 = m0_b, l0 = m0_rlast, r0 = m0_r;
      burst(m0, 4'd4, 32'h0000_5000, 256);
      for (int i = 0; i < 4000 && m0_b < b0+1; i++) tick();
      chk("T26a", (m0_b == b0+1), "256-beat INCR write did not complete");
      ar(m0, 4'd4, 32'h0000_6000, 8'd255);
      for (int i = 0; i < 6000 && m0_rlast < l0+1; i++) tick();
      chk("T26b", (m0_rlast == l0+1 && (m0_r - r0) == 256),
          $sformatf("256-beat read returned %0d beats", m0_r-r0));
    end
    tick(10);

    $display("\n=== T27: unaligned start address ===");
    begin
      int b0 = m0_b;
      burst(m0, 4'd5, 32'h0000_7002, 4);
      for (int i = 0; i < 600 && m0_b < b0+1; i++) tick();
      chk("T27", (m0_b == b0+1), "unaligned INCR write did not complete");
    end
    tick(10);

    $display("\n=== T28: burst ending exactly on a 4KB boundary ===");
    begin
      int b0 = m0_b;

      burst(m0, 4'd6, 32'h0000_0FC0, 16);
      for (int i = 0; i < 900 && m0_b < b0+1; i++) tick();
      chk("T28", (m0_b == b0+1), "burst ending on the 4KB boundary did not complete");
    end
    tick(10);

    $display("\n=== T29: AxSIZE below the bus width ===");
    begin
      int b0 = m0_b, l0 = m0_rlast;
      burst(m0, 4'd7, 32'h0000_8000, 4, 3'd0);
      burst(m0, 4'd7, 32'h0000_8100, 4, 3'd1);
      ar   (m0, 4'd7, 32'h0000_8200, 8'd3, 3'd1);
      for (int i = 0; i < 900 && (m0_b < b0+2 || m0_rlast < l0+1); i++) tick();
      chk("T29", (m0_b == b0+2 && m0_rlast == l0+1),
          $sformatf("narrow transfers: b=%0d rlast=%0d", m0_b-b0, m0_rlast-l0));
    end
    tick(10);

    $display("\n=== T30: both masters switch destination in the same cycle ===");
    begin
      int b0 = m0_b, b1 = m1_b;
      fork burst(m0, 4'd1, A_S0, 2); burst(m1, 4'd2, A_S1, 2); join
      fork burst(m0, 4'd1, A_S1, 2); burst(m1, 4'd2, A_S0, 2); join
      for (int i = 0; i < 900 && (m0_b < b0+2 || m1_b < b1+2); i++) tick();
      chk("T30", (m0_b == b0+2 && m1_b == b1+2),
          $sformatf("simultaneous destination swap: M0 %0d/2 M1 %0d/2",
                    m0_b-b0, m1_b-b1));
    end
    tick(10);

    $display("\n=== T31: all three sources at one response mux ===");
    begin
      int l0 = m0_rlast;

      ar(m0, 4'd3, A_S0,          8'd3);
      ar(m0, 4'd4, A_S1,          8'd3);
      ar(m0, 4'd5, 32'hF000_0000, 8'd3);
      for (int i = 0; i < 1500 && m0_rlast < l0+3; i++) tick();
      chk("T31", (m0_rlast == l0+3),
          $sformatf("%0d/3 read bursts returned with all three sources active",
                    m0_rlast-l0));
    end
    tick(10);

    $display("\n=== T32: completion and allocation of the same ID in one cycle ===");
    begin
      int b0 = m0_b;
      fork
        begin for (int i=0;i<10;i++) aw(m0, 4'd8, A_S0+i*64, 8'd1); end
        begin for (int i=0;i<10;i++) wr(m0, 2); end
      join
      for (int i = 0; i < 2000 && m0_b < b0+10; i++) tick();
      chk("T32a", (m0_b == b0+10),
          $sformatf("%0d/10 completed on a single pipelined ID", m0_b-b0));
      if (saw_alloc_and_cpl)
        $display("  T32b NOTE: same-cycle alloc+cpl on one ID was reached");
      else
        $display("  T32b NOTE: same-cycle alloc+cpl NOT reached -- coverage hole");
    end
    tick(10);

    $display("\n=== T33: zero-idle back-to-back writes ===");
    begin
      int b0 = m0_b;
      fork
        begin for (int i=0;i<8;i++) aw(m0, 4'd9, A_S0+i*64, 8'd0); end
        begin for (int i=0;i<8;i++) wr(m0, 1); end
      join
      for (int i = 0; i < 1500 && m0_b < b0+8; i++) tick();
      chk("T33", (m0_b == b0+8),
          $sformatf("%0d/8 single-beat writes back-to-back", m0_b-b0));
    end
    tick(10);

    $display("\n=== T34: zero-idle back-to-back reads ===");
    begin
      int l0 = m0_rlast;
      for (int i = 0; i < 8; i++) ar(m0, 4'd1, A_S0+i*64, 8'd0);
      for (int i = 0; i < 2000 && m0_rlast < l0+8; i++) tick();
      chk("T34", (m0_rlast == l0+8),
          $sformatf("%0d/8 single-beat reads back-to-back", m0_rlast-l0));
    end

    tick(20);
    $display("\n==================================");
    if (errors == 0) $display("ALL MISC TESTS PASSED");
    else             $display("%0d CHECK(S) FAILED", errors);
    $display("==================================");
    $finish;
  end

  initial begin
    #2000000;
    $display("GLOBAL TIMEOUT -- m0_b=%0d m1_b=%0d m0_rlast=%0d", m0_b, m1_b, m0_rlast);
    $finish;
  end
endmodule
