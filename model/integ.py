#!/usr/bin/env python3
"""Integration model of the crossbar WRITE path: 2 masters, 2 slaves, arbiters,
grant/release, counters, trackers.  Skids omitted (verified separately) -- AW is
driven directly with a valid/ready handshake.

WRITE PATH ONLY. Read arbitration (C3) is covered in bugrepro.py, not here.

Slave AWREADY mode matters: with combinationally-ready slaves a presented AW admits
in the same cycle, so `not adm` masks a missing `!(|s_awvalid)` in the release and
the C2 livelock is invisible. Pass registered_ready=True to expose it."""
import random
S0,S1,DE=0,1,2
MAXO,NTHR,TQ=4,2,4

class Tracker:
    def __init__(self): self.e=[{"id":0,"n":0,"d":0} for _ in range(NTHR)]
    def ok(self,qid,qd):
        act=[x["n"]!=0 for x in self.e]
        mid=[act[i] and self.e[i]["id"]==qid for i in range(NTHR)]
        mds=[mid[i] and self.e[i]["d"]==qd for i in range(NTHR)]
        return any(mds) or (not any(mid) and not all(act))
    def upd(self,qid,qd,alloc,cv,cid):
        act=[x["n"]!=0 for x in self.e]
        mid=[act[i] and self.e[i]["id"]==qid for i in range(NTHR)]
        mds=[mid[i] and self.e[i]["d"]==qd for i in range(NTHR)]
        sel=next((i for i in range(NTHR) if not act[i]),None)
        for i in range(NTHR):
            inc=alloc and (mds[i] or (not any(mid) and sel==i))
            dec=cv and act[i] and self.e[i]["id"]==cid
            if inc and not dec:
                if not act[i]: self.e[i]["id"]=qid; self.e[i]["d"]=qd
                self.e[i]["n"]+=1
            elif dec and not inc: self.e[i]["n"]-=1
    def total(self): return sum(x["n"] for x in self.e)

class Arb:
    def __init__(self): self.g=0; self.gv=0; self.last=0
    def tick(self,req,ack):
        if not (self.gv and not (self.g & ack)):
            if req:
                w=(1-self.last) if (req&1 and req&2) else (0 if req&1 else 1)
                self.g=2 if w else 1; self.gv=1; self.last=w
            else: self.g=0; self.gv=0
    @property
    def idx(self): return 1 if self.g==2 else 0

class Port:
    def __init__(self): 
        self.thr=Tracker(); self.g=0; self.dest=S0
        self.awp=0; self.wp=0; self.tc=0; self.committed=0
        self.dbusy=0; self.de_id=0; self.de_beats=0; self.de_wait=0

class Slave:
    def __init__(self,lat,reg_ready=False):
        self.lat=lat; self.inq=[]; self.pend=[]
        self.reg=reg_ready; self.rdy=0; self.saw_valid=0
    def aw_ready(self):
        # registered: assert READY the cycle AFTER seeing VALID (the common slave shape)
        return (self.rdy if self.reg else (len(self.inq)<8))
    def tick_ready(self, awv):
        self.rdy = 1 if (awv and len(self.inq)<8) else 0
    def w_ready(self):  return len(self.inq)>0
    def push_aw(self,tag,i,l): self.inq.append([tag,i,l])
    def beat(self,last):
        if last:
            t,i,l=self.inq.pop(0); self.pend.append([t,i,self.lat])
    def tick(self):
        for p in self.pend: p[2]-=1
    def b_ready_out(self):
        if self.pend and self.pend[0][2]<=0: return self.pend[0][0],self.pend[0][1]
        return None
    def pop_b(self): self.pend.pop(0)

def run(seed,cycles,s0stream,s1stream,lat0,lat1,
        fixed_release=True, registered_ready=False):
    random.seed(seed)
    P=[Port(),Port()]; A=[Arb(),Arb()]
    SL=[Slave(lat0,registered_ready),Slave(lat1,registered_ready)]
    src=[list(s0stream),list(s1stream)]
    admitted=[[],[]]; done=[[],[]]
    first_admit_after=[None,None]
    for cyc in range(cycles):
        gnt_snap=[(A[m].gv, A[m].idx) for m in (0,1)]   # registered arbiter output
        head=[src[n][0] if src[n] else None for n in (0,1)]
        awv=[h is not None for h in head]
        d=[h[0] if h else S0 for h in head]
        iid=[h[1] if h else 0 for h in head]
        ln=[h[2] if h else 0 for h in head]

        cplv=[0,0]; cplid=[0,0]
        # --- local DECERR responder: drain beats, then one B
        de_wdone=[False,False]
        for n in (0,1):
            p=P[n]
            if p.dbusy and p.de_beats>0:
                p.de_beats-=1                       # w_drop: wready is 1, beat discarded
                if p.de_beats==0: de_wdone[n]=True
            elif p.dbusy and p.de_beats==0:
                p.de_wait-=1
                if p.de_wait<=0:
                    cplv[n]=1; cplid[n]=p.de_id; p.dbusy=0; done[n].append(p.de_id)

        # --- B responses from the real slaves (routed by tag)
        for m in (0,1):
            r=SL[m].b_ready_out()
            if r:
                tag,bid=r
                if not cplv[tag]:                     # one completion per port per cycle
                    cplv[tag]=1; cplid[tag]=bid
                    SL[m].pop_b(); done[tag].append(bid)

        # --- combinational
        C=[]
        for n in (0,1):
            p=P[n]
            full=(p.awp>=MAXO) and not cplv[n]
            same=(d[n]==p.dest); free=(p.wp==0)
            needs=awv[n] and not same
            o=1-n
            cont=bool(p.g and awv[o] and d[o]==p.dest)
            close=cont and (p.tc>=TQ)
            if fixed_release: close = close and not p.committed
            thr=p.thr.ok(iid[n],d[n]) if awv[n] else False
            if d[n]==DE: ok=(not p.dbusy) and (not p.g) and free
            else:        ok=p.g and same and (not close)
            go=awv[n] and thr and (not full) and ok
            C.append(dict(full=full,same=same,free=free,needs=needs,cont=cont,
                          close=close,go=go))

        # --- arbiter requests
        req=[0,0]
        for n in (0,1):
            thr = P[n].thr.ok(iid[n],d[n]) if awv[n] else False
            if ((not P[n].g) and awv[n] and thr and (not C[n]['full'])
                    and C[n]['free'] and d[n]!=DE):
                req[d[n]] |= (1<<n)

        # --- s_awvalid: presented to the slave, must NOT depend on its READY
        sawv=[False,False]
        for n in (0,1):
            if d[n]!=DE:
                m=d[n]
                sawv[n]=C[n]['go'] and gnt_snap[m][0] and gnt_snap[m][1]==n

        # --- admission = presentation AND the slave's READY
        adm=[False,False]
        for n in (0,1):
            if d[n]==DE: adm[n]=C[n]['go']
            else:        adm[n]=sawv[n] and SL[d[n]].aw_ready()
        for n in (0,1):
            if adm[n]:
                admitted[n].append((d[n],iid[n]))
                if d[n]!=DE: SL[d[n]].push_aw(n,iid[n],ln[n])
                else:
                    P[n].dbusy=1; P[n].de_id=iid[n]
                    P[n].de_beats=ln[n]+1; P[n].de_wait=2
                src[n].pop(0)
                if first_admit_after[n] is None: first_admit_after[n]=cyc

        # --- W beats: the granted master feeds its slave
        wdone=[False,False]
        for m in (0,1):
            if gnt_snap[m][0]:
                n=gnt_snap[m][1]
                if P[n].g and P[n].dest==m and P[n].wp>0 and SL[m].w_ready():
                    last = random.random()<0.4
                    SL[m].beat(last)
                    if last: wdone[n]=True

        for n in (0,1):
            if de_wdone[n]: wdone[n]=True

        # --- release / ack
        ack=[0,0]; rel=[False,False]
        for n in (0,1):
            p=P[n]
            base = p.g and C[n]['free'] and (not adm[n]) and (C[n]['needs'] or C[n]['cont'])
            if fixed_release: base = base and not sawv[n]      # <-- the C2 fix
            rel[n]= bool(base)
            if rel[n]: ack[p.dest] |= (1<<n)

        # --- state
        for m in (0,1):
            A[m].tick(req[m],ack[m]); SL[m].tick()
            SL[m].tick_ready(any(sawv[n] and d[n]==m for n in (0,1)))
        for n in (0,1):
            if adm[n]:    P[n].committed=0
            elif sawv[n]: P[n].committed=1
        for n in (0,1):
            p=P[n]
            gt=None
            for m in (0,1):
                if gnt_snap[m][0] and gnt_snap[m][1]==n and not p.g: gt=m
            if gt is not None: p.g=1; p.dest=gt; p.tc=0
            elif rel[n]: p.g=0
            elif adm[n] and d[n]==DE: p.dest=DE
            if gt is None and adm[n] and p.tc<TQ: p.tc+=1
            p.thr.upd(iid[n],d[n],adm[n],cplv[n],cplid[n])
            if adm[n] and not cplv[n]: p.awp+=1
            elif (not adm[n]) and cplv[n]: p.awp-=1
            if adm[n] and not wdone[n]: p.wp+=1
            elif (not adm[n]) and wdone[n]: p.wp-=1
            assert 0<=p.awp<=MAXO, f"awp={p.awp} s{seed} c{cyc}"
            assert 0<=p.wp<=MAXO,  f"wp={p.wp} s{seed} c{cyc}"
            assert p.wp<=p.awp,    f"wp>awp s{seed} c{cyc}"
            assert not (p.wp>0 and not p.g and p.dest!=DE), f"beats no route s{seed} c{cyc}"
            assert p.thr.total()==p.awp, f"tracker {p.thr.total()} != awp {p.awp} s{seed} c{cyc}"

        if (not src[0] and not src[1]
                and not any(SL[m].inq or SL[m].pend for m in (0,1))
                and not any(P[n].dbusy for n in (0,1))):
            return dict(done=True,cyc=cyc,adm=admitted,got=done)
    return dict(done=False,cyc=cycles,adm=admitted,got=done,left=[len(src[0]),len(src[1])])

if __name__=="__main__":
    print("=== A. both masters stream to the SAME slave ===")
    r=run(1,20000,[(S0,i%4,3) for i in range(12)],[(S0,i%4,3) for i in range(12)],6,6)
    print(f"  drained={r['done']} cycles={r['cyc']}  M0 {len(r['adm'][0])}/12  M1 {len(r['adm'][1])}/12")
    print(f"  B responses: M0 {len(r['got'][0])}  M1 {len(r['got'][1])}")

    print()
    print("=== B. concurrent independent (M0->S0, M1->S1) ===")
    r=run(2,20000,[(S0,i%4,3) for i in range(12)],[(S1,i%4,3) for i in range(12)],6,6)
    print(f"  drained={r['done']} cycles={r['cyc']}  M0 {len(r['adm'][0])}/12  M1 {len(r['adm'][1])}/12")

    print()
    print("=== C. destination switching + DECERR mixed ===")
    random.seed(7)
    a=[(random.choice([S0,S1,DE]),random.randrange(4),3) for _ in range(20)]
    b=[(random.choice([S0,S1,DE]),random.randrange(4),3) for _ in range(20)]
    r=run(3,30000,a,b,4,9)
    print(f"  drained={r['done']} cycles={r['cyc']}  M0 {len(r['adm'][0])}/20  M1 {len(r['adm'][1])}/20")

    print()
    print("=== D. randomised soak ===")
    fails=hangs=0; firstmsg=None
    for seed in range(300):
        random.seed(seed)
        a=[(random.choice([S0,S1]),random.randrange(4),random.choice([0,1,3])) for _ in range(8)]
        b=[(random.choice([S0,S1]),random.randrange(4),random.choice([0,1,3])) for _ in range(8)]
        try:
            r=run(seed,30000,a,b,random.choice([2,5,11]),random.choice([2,5,11]))
            if not r['done']: hangs+=1; firstmsg=firstmsg or f"seed {seed} left {r['left']}"
        except AssertionError as e:
            fails+=1; firstmsg=firstmsg or str(e)
    print(f"  300 seeds: {fails} invariant failures, {hangs} did not drain")
    if firstmsg: print("  first:",firstmsg)

    # ---------------------------------------------------------------- seams
    print()
    print("=== E. starvation bound: M0 streams, M1 asks once ===")
    st0=[(S0,i%4,3) for i in range(40)]
    st1=[(S0,9,3)]
    r=run(11,20000,st0,st1,5,5)
    # cycle at which M1's single AW was admitted
    print(f"  drained={r['done']}  M0 admitted {len(r['adm'][0])}  M1 admitted {len(r['adm'][1])}")
    print(f"  -> M1 was served, not starved" if len(r['adm'][1])==1 else "  -> M1 STARVED")

    print()
    print("=== F. livelock check: both stream forever, symmetric ===")
    st=[(S0,i%4,3) for i in range(60)]
    r=run(12,40000,list(st),list(st),5,5)
    a,b=len(r['adm'][0]),len(r['adm'][1])
    print(f"  drained={r['done']} cycles={r['cyc']}  M0={a}  M1={b}")
    print(f"  ratio={min(a,b)/max(a,b):.2f} -> {'both progress, no livelock' if min(a,b)>0 else 'LIVELOCK'}")

    print()
    print("=== G. concurrency: independent pairs must not serialise ===")
    n=16
    rc=run(21,20000,[(S0,i%4,3) for i in range(n)],[(S1,i%4,3) for i in range(n)],5,5)
    rs=run(22,20000,[(S0,i%4,3) for i in range(n)],[(S0,i%4,3) for i in range(n)],5,5)
    print(f"  concurrent (S0||S1): {rc['cyc']} cycles")
    print(f"  contended  (both S0): {rs['cyc']} cycles")
    print(f"  -> ratio {rs['cyc']/rc['cyc']:.2f}x  ({'concurrent is genuinely parallel' if rs['cyc']>rc['cyc']*1.3 else 'SERIALISED?'})")

    print()
    print("=== H. same ID to S0 then DECERR -- ordering must hold ===")
    # ID 3 to S0 (slow), then ID 3 to a bad address (fast local responder)
    r=run(31,20000,[(S0,3,3),(DE,3,3)],[],20,20)
    order=r['got'][0]
    print(f"  drained={r['done']}  completion order for M0: {order}")
    print(f"  admitted order: {[x[0] for x in r['adm'][0]]}")
    print("  -> the tracker blocks the DECERR until S0's B returns, so both are id 3 in issue order")

    # ------------------------------------------------- C2 regression (scenario F')
    print()
    print("=== F'. C2 REGRESSION: registered-AWREADY slave, symmetric contention ===")
    st=[(S0,i%4,3) for i in range(40)]
    for label,fx in (("old release (no !s_awvalid)",False),("fixed release",True)):
        r=run(99,4000,list(st),list(st),5,5,fixed_release=fx,registered_ready=True)
        a,b=len(r['adm'][0]),len(r['adm'][1])
        verdict = "LIVELOCK" if (a+b)==0 else ("starved" if min(a,b)==0 else "both progress")
        print(f"  {label:<30} M0={a:3d} M1={b:3d}  -> {verdict}")
    print("  -> the old release must fail here; that is what makes this a regression test")
