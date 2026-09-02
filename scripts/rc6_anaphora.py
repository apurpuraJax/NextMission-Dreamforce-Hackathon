"""NMDH-36. "Of those, which one" must resolve to the list just offered."""
import re, json, urllib.request, textwrap, re
from concurrent.futures import ThreadPoolExecutor
BASE="https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute"
def call(m,p):
    b={"namespace":"","classname":"NM_AgentController","method":m,"params":p,"cacheable":False,"isContinuation":False}
    r=urllib.request.Request(BASE,data=json.dumps(b).encode(),headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(r,timeout=200).read())
def conv(t):
    sid=call("startSession",{"sourceUrl":"https://rc6"})["returnValue"]["sessionId"]
    out=[]
    for x in t:
        try: out.append((call("sendMessage",{"sessionId":sid,"text":x,"sourceUrl":"https://rc6"})["returnValue"].get("replyText") or "").strip())
        except Exception as e: out.append("ERROR "+str(e)[:80])
    return out
PICK=["most realistic","closest","based on what you","i would start","best fit","strongest","start with",
      "most direct","i'd go","recommend","the one i","go for"]
CASES=[
 ("of those, which one",   ["Coast Guard BM","the roles it matches","i don't have a captain's license and don't want to be on the water anymore. what else fits?","of those, which one should i actually go for and why?"]),
 ("which of these",        ["navy avionics technician, electronics on F/A-18s","what jobs fit","which of these should i go for first?"]),
 ("between those",         ["i ran a supply warehouse in the army, managed inventory and a team","what jobs fit","between those, which is the better bet for me?"]),
]
def run(c):
    n,t=c; r=conv(t); last=r[-1].lower()
    picks=[p for p in PICK if p in last]
    # A re-list is the failure mode: printing the roster again instead of
    # choosing. Count LINES shaped like "Title: description", not bare colons —
    # a prose answer that characterises each alternative is a good answer, and
    # wage lines put colons everywhere, so counting colons flagged both.
    relist = sum(1 for ln in r[-1].split('\n')
                 if re.match(r'^\s*[A-Z][^:\n]{3,60}:\s+\S', ln)) >= 4
    return n,r,picks,relist
with ThreadPoolExecutor(max_workers=3) as ex: res=list(ex.map(run,CASES))
ok=True
for n,r,picks,relist in res:
    good = bool(picks) and not relist
    ok &= good
    print(("PASS  " if good else "FAIL  ")+n)
    if not good:
        print("        recommends: %s | re-listed: %s" % (bool(picks), relist))
        print("        %s" % textwrap.shorten(r[-1],200))
print("\n"+("RC6 CLEAN" if ok else "RC6 NEEDS WORK"))
