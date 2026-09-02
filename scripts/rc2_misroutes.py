import json, urllib.request, textwrap
from concurrent.futures import ThreadPoolExecutor
BASE="https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute"
def call(m,p):
    b={"namespace":"","classname":"NM_AgentController","method":m,"params":p,"cacheable":False,"isContinuation":False}
    r=urllib.request.Request(BASE,data=json.dumps(b).encode(),headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(r,timeout=200).read())
def conv(t):
    sid=call("startSession",{"sourceUrl":"https://rc2"})["returnValue"]["sessionId"]
    out=[]
    for x in t:
        try: out.append((call("sendMessage",{"sessionId":sid,"text":x,"sourceUrl":"https://rc2"})["returnValue"].get("replyText") or "").strip())
        except Exception as e: out.append("ERROR "+str(e)[:80])
    return out
CASES=[
 ("F5  nuclear",   ["i was a machinist mate on a navy nuclear submarine, ran the reactor plant","what jobs fit"], ["reactor","power plant","stationary"], ["construction project manager","heavy equipment operator"]),
 ("F1  avionics",  ["navy avionics technician, troubleshot electronics and instrument systems on F/A-18s","what civilian jobs fit"], ["avionics"], ["airline pilot"]),
 ("F7  cook",      ["i was a cook in the army for 8 years, ran a dining facility feeding 800 soldiers","what jobs fit"], ["chef","food service","cafeteria"], []),
 ("F12 SAR",       ["coast guard cutter, search and rescue, small boat ops, first aid, pulling people out of the surf","what jobs fit"], ["paramedic","emergency medical","firefighter","lifeguard"], ["police officer","corrections"]),
 ("F13 diesel",    ["coast guard machinery technician, diesel engines, pumps, hydraulics on the cutters","what jobs fit"], ["diesel","machinery","maintenance"], ["construction project manager"]),
 ("F8  imagery",   ["imagery analyst in the air force, satellite and drone footage, mapping targets","what civilian jobs fit"], ["remote sensing","cartograph","mapping"], []),
]
def run(c):
    n,t,want,ban=c; r=conv(t); blob=" ".join(r).lower()
    hit=[w for w in want if w in blob]; bad=[b for b in ban if b in blob]
    return n,r,hit,bad
with ThreadPoolExecutor(max_workers=6) as ex: res=list(ex.map(run,CASES))
ok=True
for n,r,hit,bad in res:
    good = bool(hit) and not bad
    ok &= good
    print(("PASS  " if good else "FAIL  ")+n)
    if hit: print("        found: %s" % hit)
    if bad: print("        STILL OFFERS: %s" % bad)
    if not good: print("        %s" % textwrap.shorten(r[-1],180))
print("\n"+("RC2 CLEAN" if ok else "RC2 NEEDS WORK"))
