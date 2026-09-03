#!/usr/bin/env python3
"""Reproduce C1/C2/C3 in models, then re-run against the fixed logic.

The originals missed all three because the endpoints were idealised:
  C1  sources were always valid          -> now they empty, and R bursts gap
  C2  slaves were combinationally ready  -> now AWREADY is registered
  C3  the read path was never modelled   -> now it is
"""

# ---------------------------------------------------------------- C1
class Mux:
    """resp_return_mux. fixed=False is the shipped RTL."""
    def __init__(self, burst_atomic=False, fixed=False):
        self.ba = burst_atomic; self.fixed = fixed
        self.sel = 0; self.sv = 0; self.last_sel = 0; self.mid = 0

    def cycle(self, s_valid, s_last, m_ready):
        req = [s_valid[0], s_valid[1], 0]
        m_last = s_last[self.sel] if self.sel < 2 else 0
        if self.fixed:
            m_valid = self.sv and req[self.sel]
        else:
            m_valid = self.sv                       # shipped RTL
        done = m_valid and m_ready and (m_last if self.ba else True)
        if self.fixed:
            held = self.sv and not done and (self.mid or req[self.sel])
        else:
            held = self.sv and not done
        phantom = bool(m_valid and not req[self.sel])
        if self.fixed and self.ba:
            if m_valid and m_ready and not m_last: self.mid = 1
            elif done:                             self.mid = 0
        if not held:
            order = {0: [1, 2, 0], 1: [2, 0, 1], 2: [0, 1, 2]}[self.last_sel]
            f = next((c for c in order if req[c]), None)
            self.sv = 1 if f is not None else 0
            if f is not None: self.sel = f; self.last_sel = f
        return phantom, held, m_valid

def c1_single_response(fixed):
    m = Mux(burst_atomic=False, fixed=fixed)
    ph = 0
    m.cycle([1, 0], [1, 1], 0)          # B present, arbitrate
    m.cycle([1, 0], [1, 1], 1)          # handshake, skid pops
    for _ in range(4):
        p, _, _ = m.cycle([0, 0], [0, 0], 1)   # source empty
        ph += p
    return ph

def c1_rvalid_gap(fixed):
    """4-beat R burst with a 2-cycle gap after beat 2."""
    m = Mux(burst_atomic=True, fixed=fixed)
    ph = 0; delivered = 0
    seq = [(1,0),(1,0),(0,0),(0,0),(1,0),(1,1)]   # (valid, last)
    m.cycle([1, 0], [0, 0], 0)
    for v, l in seq:
        p, _, mv = m.cycle([v, 0], [l, 0], 1)
        ph += p
        if mv: delivered += 1
    return ph, delivered

def c1_deadlock_check(fixed):
    """After a COMPLETE burst from S0, S0 goes quiet and S1 has work.
    A naive m_valid=sel_valid&&req[sel] with held=sel_valid&&!done would lock
    onto the drained S0 forever. The mid_burst form must release."""
    m = Mux(burst_atomic=True, fixed=fixed)
    m.cycle([1, 0], [1, 0], 0)          # select S0
    m.cycle([1, 0], [1, 0], 1)          # single-beat burst, LAST -> done
    for _ in range(20):                 # S0 quiet, S1 waiting
        _, held, _ = m.cycle([0, 1], [0, 1], 1)
        if m.sel == 1 and m.sv: return 0        # switched to S1: healthy
    return 1                                     # never switched: locked

# ---------------------------------------------------------------- C2
def c2_livelock(fixed, cycles=200):
    """Both masters want S0. Slave registers AWREADY off AWVALID.

    CALIBRATION: this model derives one shared aw_ready from any(s_awvalid), so
    whichever port happens to align with it makes progress -- the shipped-mode
    signature here is STARVATION (M0=80 M1=0), not the RTL's mutual livelock.
    integ.py scenario F' reproduces the true signature (both zero) because it
    models the registered arbiter output and therefore the dead cycle between
    release and the new grant taking effect. Keep this as a regression marker,
    not as a statement of what the RTL does."""
    TQ = 4
    class P:
        def __init__(s): s.g=0; s.tc=0; s.wp=0; s.awp=0; s.committed=0
    P0, P1 = P(), P()
    grant = None            # which master holds S0
    aw_ready = 0            # slave: registered, follows last cycle's awvalid
    admits = [0, 0]
    prev_awvalid = 0
    for _ in range(cycles):
        ports = [P0, P1]
        s_awvalid = [0, 0]
        for n, p in enumerate(ports):
            contested = bool(p.g and True)          # the other master always wants S0
            close = contested and (p.tc >= TQ)
            if fixed: close = close and not p.committed
            aw_go = bool(p.g and not close)
            s_awvalid[n] = int(aw_go)
        aw_admit = [0, 0]
        for n, p in enumerate(ports):
            if s_awvalid[n] and aw_ready: aw_admit[n] = 1
        rel = [0, 0]
        for n, p in enumerate(ports):
            contested = bool(p.g)
            free = (p.wp == 0)
            base = p.g and free and not aw_admit[n] and contested
            if fixed: base = base and not s_awvalid[n]
            rel[n] = int(base)
        nxt_ready = 1 if any(s_awvalid) else 0      # registered AWREADY
        for n, p in enumerate(ports):
            if fixed:
                if s_awvalid[n] and not aw_admit[n]: p.committed = 1
                elif aw_admit[n]:                    p.committed = 0
            if aw_admit[n]:
                admits[n] += 1; p.tc = min(p.tc+1, TQ); p.wp += 1
            if p.wp > 0 and aw_admit[n] == 0: p.wp = max(0, p.wp-1)   # drains
            if rel[n]: p.g = 0
        if grant is None or not ports[grant].g:
            grant = 1 if grant in (None, 0) else 0
            ports[grant].g = 1; ports[grant].tc = 0
        aw_ready = nxt_ready
    return admits

# ---------------------------------------------------------------- C3
class Arb:
    def __init__(self, hold_idle=True):
        self.hi = hold_idle; self.g=0; self.gv=0; self.last=0
    def cycle(self, req, ack):
        held = self.gv and not (self.g & ack)
        if not self.hi: held = held and bool(self.g & req)
        if not held:
            if req:
                w = (1-self.last) if (req & 1 and req & 2) else (0 if req & 1 else 1)
                self.g = 2 if w else 1; self.gv = 1; self.last = w
            else:
                self.g = 0; self.gv = 0
        return held

def c3_stale_grant(hold_idle):
    a = Arb(hold_idle)
    a.cycle(0b01, 0)                 # M0 presents
    a.cycle(0b01, 0b01)              # handshake -> ack
    a.cycle(0b00, 0)                 # M0 empty
    served = 0
    for _ in range(30):              # M1 now wants the slave
        a.cycle(0b10, 0)
        if a.gv and a.g == 0b10: served = 1; break
    return served

def c3_no_bubble(hold_idle):
    """back-to-back ARs from one master must not lose a cycle."""
    a = Arb(hold_idle); grants = 0
    for _ in range(8):
        a.cycle(0b01, 0b01 if a.gv and a.g == 0b01 else 0)
        if a.gv and a.g == 0b01: grants += 1
    return grants

def c3_write_tenure(hold_idle):
    """a write tenure holds with req low; hold_idle=0 would destroy it."""
    a = Arb(hold_idle)
    a.cycle(0b01, 0)                 # granted
    held_cycles = 0
    for _ in range(10):              # req low (arb_req is masked by !mw_grant)
        if a.cycle(0b00, 0): held_cycles += 1
    return held_cycles


if __name__ == "__main__":
    for label, fixed in (("SHIPPED RTL", False), ("FIXED", True)):
        print(f"================ {label} ================")
        p = c1_single_response(fixed)
        print(f"  C1 single B, source empties : phantom beats = {p}")
        ph, dl = c1_rvalid_gap(fixed)
        print(f"  C1 R burst with RVALID gap  : phantom beats = {ph}, delivered = {dl} (want 4)")
        st = c1_deadlock_check(fixed)
        print(f"  C1 drained source, S1 waiting: locked = {st} (want 0)")
        adm = c2_livelock(fixed)
        print(f"  C2 registered AWREADY       : admissions M0={adm[0]} M1={adm[1]}")
        print()
    print("================ C3 (arbiter mode) ================")
    for label, hi in (("hold_idle=1 (shipped)", True), ("hold_idle=0 (read fix)", False)):
        print(f"  {label}")
        print(f"    M1 served after M0 idles : {c3_stale_grant(hi)} (want 1)")
        print(f"    back-to-back grants      : {c3_no_bubble(hi)}/8")
        print(f"    write tenure held        : {c3_write_tenure(hi)}/10 (want 10 for write)")
