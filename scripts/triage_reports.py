"""Re-run the reported repro steps against the CURRENTLY ACTIVE agent.

The three Orchestrate reports were produced across v50-v53 and each says it
could not confirm which version served a given reply. Several fixes landed
mid-run. So before designing anything, establish which findings STILL
reproduce on the live version.
"""
import json, urllib.request, urllib.error, sys, re, textwrap
from concurrent.futures import ThreadPoolExecutor

BASE = "https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute"

def call(method, params, timeout=200):
    p = {"namespace":"","classname":"NM_AgentController","method":method,
         "params":params,"cacheable":False,"isContinuation":False}
    r = urllib.request.Request(BASE, data=json.dumps(p).encode(),
                               headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(r, timeout=timeout).read())

def converse(turns):
    sid = call("startSession", {"sourceUrl":"https://triage"})["returnValue"]["sessionId"]
    out=[]
    for t in turns:
        try:
            rv = call("sendMessage", {"sessionId":sid,"text":t,"sourceUrl":"https://triage"})["returnValue"]
            out.append((rv.get("replyText") or "").strip())
        except Exception as e:
            out.append("ERROR "+str(e)[:100])
    return out

# id, report, description, turns, still_reproduces(replies) -> bool
CASES = [
 ("D02-D","D02","Helicopter free-text flips to construction when rank is added",
  ["I fixed helicopters in the Marines","i was a master sergeant","that works"],
  lambda r: any(w in " ".join(r).lower() for w in
      ["construction project manager","heavy equipment operator","estimator"])),

 ("D02-E","D02","Mentor re-described verbatim on repeated yes",
  ["I fixed helicopters in the Marines","what jobs fit","connect me with a mentor","yes","yes"],
  lambda r: len(r)>4 and _sim(r[3],r[4])>0.75),

 ("D01-A","D01","Coast Guard IT does not echo the crosswalk role title",
  ["Coast Guard IT","show me civilian roles"],
  lambda r: "information system" not in " ".join(r).lower()),

 ("D01-B","D01","Pay question repetition loop",
  ["Navy IT here","which one pays the best?","which one pays the best?","which one pays the best?"],
  lambda r: len(r)>3 and (_sim(r[1],r[2])>0.75 or _sim(r[2],r[3])>0.75)),

 ("D01-C","D01","Cook describe-path fallback loop",
  ["I was a cook feeding 500 troops a day","ok, what's next?",
   "are you sure those actually fit what I did?","are you sure those actually fit what I did?"],
  lambda r: len(r)>3 and (_sim(r[2],r[3])>0.8 or "do not have data" in r[3].lower())),

 ("D03-F3","D03","Coast Guard BM2 paygrade suffix not normalised",
  ["Coast Guard BM2","show me roles"],
  lambda r: any(p in r[0].lower() for p in ["do not have","don't have","not have that code"])),

 ("D03-F18","D03","Air Force AFSC X-form 1B4X1 not resolved",
  ["Air Force 1B4X1, cyber warfare operations"],
  lambda r: any(p in r[0].lower() for p in ["do not have","don't have","not have that code"])),

 ("D03-F1","D03","Avionics free-text offered pilot/ATC",
  ["i spent 12 years in the navy as an avionics technician. i troubleshot and repaired the electronics and instrument systems on F/A-18s","what civilian jobs does that translate to?"],
  lambda r: any(w in " ".join(r).lower() for w in ["airline pilot","air traffic controller"])),

 ("D03-F4","D03","Military-only SOC surfaced as a civilian occupation",
  ["Army 11B","show me the roles"],
  lambda r: "infantry" in " ".join(r).lower()),

 ("D03-F14","D03","Marine 0311 hard refusal when asked for civilian titles",
  ["Marine Corps, 0311, did two deployments as a rifleman and team leader","show me the civilian roles it matches",
   "that's just my military job again. i can't get hired as 'infantry'. what actual civilian jobs use what i did?",
   "so what civilian jobs actually fit those skills? give me real titles i can apply to."],
  lambda r: any("can't assist" in x.lower() or "cannot assist" in x.lower() for x in r)),

 ("D03-F5","D03","Navy nuclear free-text routed to construction",
  ["i was a machinist mate on a navy nuclear submarine, ran the reactor plant","what jobs fit"],
  lambda r: any(w in " ".join(r).lower() for w in ["construction project manager","heavy equipment operator"])),

 ("D03-F11","D03","Domain switch leaves occupation list stuck on first cluster",
  ["I did a bit of everything in the Army - started as a mechanic, then moved into supply, and my last few years I was basically running IT for the unit.",
   "That's only the supply part. My most recent work was IT - running the network, user accounts, help desk. That's what I want to do.",
   "Show me those IT roles then."],
  lambda r: any(p in " ".join(r).lower() for p in
      ["do not have those","don't have those","not in my current list","not in my set"])),
]

import difflib
def _sim(a,b): return difflib.SequenceMatcher(None,a.lower(),b.lower()).ratio()

def run(c):
    cid, rep, desc, turns, check = c
    replies = converse(turns)
    try: still = check(replies)
    except Exception: still = None
    return cid, rep, desc, turns, replies, still

if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=6) as ex:
        results = list(ex.map(run, CASES))
    print("="*78)
    print("REPRO CHECK AGAINST THE LIVE AGENT")
    print("="*78)
    for cid, rep, desc, turns, replies, still in sorted(results):
        mark = "STILL BROKEN" if still else ("FIXED       " if still is False else "UNKNOWN     ")
        print("  %-9s %-4s %s  %s" % (cid, rep, mark, desc))
    print()
    for cid, rep, desc, turns, replies, still in sorted(results):
        if still:
            print("-"*78)
            print("%s — %s" % (cid, desc))
            for i,(t,r) in enumerate(zip(turns,replies),1):
                print("  %d> %s" % (i,t))
                print("     %s" % textwrap.shorten(r, 165))
