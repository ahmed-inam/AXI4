# ============================================================================
# AXI4 2x2 Crossbar
#
#   make              compile RTL + linear benches
#   make regress      run every linear bench
#   make sim SIM_TOP=tb_grant
#   make class        compile the class-based TB
#   make csim         run the class-based TB
#   make csim TEST=t17
#   make clean
#
# Two testbench flows share one RTL tree:
#   tb_lin/    module-based benches, one file per bench, all compiled
#   tb_class/  class-based TB; only the package and tb_top are compiled,
#              everything else is `include`d, so xvlog needs -i tb_class
# ============================================================================

RTL := \
  rtl/axi4_pkg.sv \
  rtl/axi4_if.sv \
  rtl/rst_sync.sv \
  rtl/skid_buffer.sv \
  rtl/addr_decoder.sv \
  rtl/rr_arbiter.sv \
  rtl/thread_tracker.sv \
  rtl/decerr_wr_resp.sv \
  rtl/decerr_rd_resp.sv \
  rtl/resp_return_mux.sv \
  rtl/wr_port_ctrl.sv \
  rtl/rd_port_ctrl.sv \
  rtl/slave_wr_port.sv \
  rtl/slave_rd_port.sv \
  rtl/axi4_xbar_top.sv \
  rtl/axi4_assert.sv

TB_LIN := \
  tb_lin/axi4_cov.sv \
  tb_lin/xbar_wrap.sv \
  tb_lin/tb_smoke.sv \
  tb_lin/tb_ext.sv \
  tb_lin/tb_grant.sv \
  tb_lin/tb_misc.sv \
  tb_lin/tb_score.sv \
  tb_lin/tb_rand.sv

TB_CLASS := \
  tb_class/xbar_probe_if.sv \
  tb_class/axi4_tb_pkg.sv \
  tb_class/tb_top.sv

CLASS_INC := -i tb_class

LIN_SRCS   := $(RTL) $(TB_LIN)
CLASS_SRCS := $(RTL) $(TB_CLASS)

ELAB_TOP ?= xbar_wrap
SIM_TOP  ?= tb_smoke
TEST     ?= smoke

LIN_BENCHES := tb_smoke tb_ext tb_grant tb_misc tb_score tb_rand

.PHONY: all compile compile_noassert elab sim regress class csim clean help

all: compile

check-%:
	@for f in $($*); do \
	  [ -f "$$f" ] || { echo "MISSING: $$f"; exit 1; }; \
	done

compile: check-LIN_SRCS
	@echo "== $(words $(LIN_SRCS)) files =="
	xvlog -sv $(LIN_SRCS)

compile_noassert:
	xvlog -sv $(filter-out rtl/axi4_assert.sv,$(LIN_SRCS))

elab: compile
	xelab -relax -debug typical -s xbar $(ELAB_TOP)

sim: compile
	xelab -relax -debug typical -s xbar_sim $(SIM_TOP)
	xsim xbar_sim -runall

regress:
	@for t in $(LIN_BENCHES); do \
	  echo "=================== $$t ==================="; \
	  $(MAKE) --no-print-directory sim SIM_TOP=$$t 2>&1 | \
	    grep -E "PASS|FAIL|CLEAN|ERROR|COVERAGE" || true; \
	done

class: check-CLASS_SRCS
	@echo "== $(words $(CLASS_SRCS)) files (class TB) =="
	xvlog -sv $(CLASS_INC) $(CLASS_SRCS)

csim: class
	xelab -relax -debug typical -s xbar_class tb_top
	xsim xbar_class -runall -testplusarg TEST=$(TEST) 2>&1 | tee csim_$(TEST).log
	@! grep -qE "%Error|: ERROR|VERDICT: FAIL|Fatal" csim_$(TEST).log

CLASS_TESTS := smoke cross cross_rd decerr t7 t9 t10 t11 t13 t14 t15 t16 t17 \
               t20 t21 t22 committed rd_handover rstwin bursts
CSEEDS      := 1 2 3 5 13

cregress: class
	xelab -relax -debug typical -s xbar_class tb_top
	@fail=0; \
	for t in $(CLASS_TESTS); do \
	  xsim xbar_class -runall -testplusarg TEST=$$t > creg_$$t.log 2>&1; \
	  if grep -qE "%Error|: ERROR|VERDICT: FAIL|Fatal" creg_$$t.log; \
	  then echo "  $$t FAIL"; fail=1; else echo "  $$t pass"; fi; \
	done; \
	for s in $(CSEEDS); do \
	  xsim xbar_class -runall -testplusarg TEST=random -testplusarg NTXN=300 \
	       -sv_seed $$s > creg_rand$$s.log 2>&1; \
	  if grep -qE "%Error|: ERROR|VERDICT: FAIL|Fatal" creg_rand$$s.log; \
	  then echo "  random seed $$s FAIL"; fail=1; else echo "  random seed $$s pass"; fi; \
	done; \
	exit $$fail

clean:
	rm -rf xsim.dir *.jou *.log *.pb *.wdb .Xil

help:
	@echo "  make                      compile RTL + tb_lin"
	@echo "  make regress              run every linear bench"
	@echo "  make sim SIM_TOP=tb_grant run one linear bench"
	@echo "  make class                compile the class TB"
	@echo "  make csim TEST=t17        run one class test"
	@echo "  make clean"