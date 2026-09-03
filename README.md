# AXI4 2x2 Crossbar

A synthesizable AXI4 crossbar connecting two masters to two slaves, written in
SystemVerilog, with two independent testbench flows and an RTL-side protocol
checker.

Full AXI4 five-channel signalling: independent AW/W/B/AR/R channels, bursts
(FIXED / INCR / WRAP), write strobes, narrow and unaligned transfers, multiple
outstanding transactions, ID-based response routing, and DECERR for unmapped
addresses. `AxLOCK`, `AxCACHE`, `AxPROT` and `AxQOS` are out of scope.

## Configuration

| Parameter | Value | Meaning |
|---|---|---|
| `NUM_MASTERS` / `NUM_SLAVES` | 2 / 2 | fabric is fixed 2x2 (elaboration-checked) |
| `DATA_WIDTH` / `ADDR_WIDTH` | 32 / 32 | |
| `ID_WIDTH` | 4 | master-facing; slave-facing is 5 (`M_ID_W`), the extra bit tags the master |
| `MAX_OUTSTANDING` | 4 | transactions per direction per port |
| `NUM_THREADS` | 2 | distinct in-flight IDs per port; must be `< MAX_OUTSTANDING` |
| `TENURE_QUANTUM` | 4 | guaranteed admissions per grant tenure |

Address map: `0x0xxx_xxxx` -> S0, `0x1xxx_xxxx` -> S1, anything else -> DECERR,
returned locally by the crossbar. Regions are 256 MB and power-of-two aligned,
so decode is an upper-nibble compare.

## Layout

    rtl/        16 files -- the crossbar and its protocol checker
    tb/tb_lin/   8 files -- module-based benches (6 benches, wrapper, coverage)
    tb/tb_class/15 files -- class-based TB (agents, drivers, monitors, ref model,
                            scoreboard, sequences, 22 tests)
    model/       Python reference models used during bring-up

## Build

Developed against AMD Vivado XSim; both regressions also pass under Verilator
5.020 (`--timing --assert`). On Verilator 5.050 and later the RTL, the class TB
and four of the six linear benches still lint clean, but `tb_score` and `tb_rand`
are rejected: their associative-array slave memories use nonblocking assignment,
which newer versions enforce against per IEEE 1800-2023 section 6.21.

```bash
make                  # compile RTL + linear benches
make regress          # run every linear bench
make sim SIM_TOP=tb_grant
make class            # compile the class-based TB
make csim TEST=t17    # run one class test (fails the make on any error)
make cregress         # 20 class tests + 5 random seeds, aggregated exit status
```

`axi4_xbar_top` has interface ports, so it cannot be an xelab top.
`tb_lin/xbar_wrap.sv` and `tb_class/tb_top.sv` exist to give xelab a module with
ordinary ports.

## Architecture

Each master port owns its write and read control (`wr_port_ctrl`, `rd_port_ctrl`),
a per-ID ordering guard (`thread_tracker`), a local error responder, and a
response return mux. Each slave port arbitrates between the two masters
(`rr_arbiter`) and muxes the winner's payload. All boundaries are registered
through `skid_buffer`, so no combinational path crosses the fabric.

The write path grants a **tenure**, not a burst: a master holds a slave until it
targets a different one or contention forces handover, and `TENURE_QUANTUM`
guarantees forward progress before the door can close. Releasing on a bare
contention signal livelocks -- a fresh tenure sees the sibling already asking,
admits nothing, and releases immediately.

Reads take no tenure. AR carries its own address, so nothing is remembered
between transfers and a master's reads may target both slaves at once; the read
arbiter therefore acks per transfer and must drop an idle grant.

Responses route by the tag bit added to the ID at admission. `resp_return_mux`
selects among S0, S1 and the local DECERR responder, strips the tag, and drives
one completion tap that frees both the pending counter and the tracker entry --
they must never diverge.

`axi4_assert.sv` is bound into every interface instance and checks handshake
stability, burst legality, the 4KB rule, WLAST/RLAST beat counts, and the A3.3
response dependency at the cycle a violation happens.

## Testbench flows

**Linear** (`tb_lin/`) -- 34 directed tests across six benches, end-to-end
scoreboard, constrained random with functional coverage:

| bench | what |
|---|---|
| `tb_smoke` | T1-T2, basic write plus the cross-master response regression |
| `tb_ext`   | T3-T8, read path, DECERR both directions, contention |
| `tb_grant` | T9-T18, grant lifecycle and every admission gate |
| `tb_misc`  | T19-T34, reset, burst variety, simultaneity |
| `tb_score` | scoreboard: data, IDs, ordering, beat counts, leak check |
| `tb_rand`  | constrained random plus functional coverage (`+ntxn=N`) |

**Class-based** (`tb_class/`) -- four agents, reference model, scoreboard.

`+TEST=<name>`: `smoke cross cross_rd decerr t7 t9 t10 t11 t13 t14 t15 t16 t17
t20 t21 t22 committed rd_handover rstwin example bursts random`.
`+TEST=<number>` runs constrained random with that many transactions **per
master** -- all directions, burst types and sizes, DECERR/SLVERR, unaligned INCR,
mid-container WRAP, hostile READY timing.

`+VERBOSITY=N`: 0 verdicts only, 1 default, 2 adds a build trace, 3 adds
per-transaction monitor traffic. Every run ends with one aggregated
`FINAL VERDICT` line folding scoreboard, outstanding, local and monitor errors.

Adding a directed test is a subclass, a `TEST_CTOR` line, a `body()` of `push()`
calls, and one registration line in `tb_top` -- see `axi4_test_example`.

## Status

Linear: 34 directed tests, 15 random seeds, all pass. 144/144 reachable RTL
lines and 108/108 reachable functional coverage bins (linear-flow measurement;
class-flow coverage is the open item).

Class: 20 directed tests plus random, all pass behind `FINAL VERDICT`.

**Mutation-tested: 9/9 killed.** Nine bugs were injected, including every
historical critical. Three initially escaped the class flow -- a same-cycle-ready
BFM idiom, an unreachable guard race, and an unstimulated reset window. Each
escape was root-caused, fixed, and now has a directed test that kills it
(`committed`, `rd_handover`, `rstwin`).

`model/` holds the Python models this work ran on: `integ.py` is an integration
model of the write path, `bugrepro.py` reproduces three critical bugs against
both the original and the fixed logic.

### Known limitations

- Deadlock freedom and the starvation bound are argued, not proven. Formal is
  the highest-value item outstanding.
- Documented stimulus gap: R-beat interleaving from the slave BFM.
- Exclusive access, low-power and QoS signalling are not implemented.

## Simulator notes

Behaviours that cost real debugging time here, recorded because they fail
silently rather than loudly:

- Verilator evaluates SVA only with `--assert`. Without it the properties
  compile and do nothing -- an entire checker was off and no log said so.
- `$error` is non-fatal on some simulators. Aggregate into one verdict line and
  grep it in the make target, or errors scroll past and the run reports PASS.
- `str[i] inside {["0":"9"]}` evaluated false on every digit in one simulator.
  Compare byte values instead (`< "0" || > "9"`).
- A slave BFM whose READY reacts in the same cycle as VALID can never make the
  DUT wait, so every bug that lives in the waiting state is invisible.
  `awready = awvalid && !awready` at the negedge is that idiom in disguise.
- A `parameter bit` override was silently ignored once, reintroducing a fixed
  bug. Check behaviour-selecting parameters at run time.
- One process per counter, or same-cycle events silently cancel.
- Declare TB variables before use; one simulator enforces it, the other does not.
- Do not put queue methods in continuous assigns.
