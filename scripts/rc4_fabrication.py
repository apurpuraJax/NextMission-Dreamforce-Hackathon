"""NMDH-35. Push the agent into situations where grounded retrieval cannot help,
then check whether it invents job titles or admits the gap."""
import json, urllib.request, textwrap
from concurrent.futures import ThreadPoolExecutor
BASE="https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute"
def call(m,p):
    b={"namespace":"","classname":"NM_AgentController","method":m,"params":p,"cacheable":False,"isContinuation":False}
    r=urllib.request.Request(BASE,data=json.dumps(b).encode(),headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(r,timeout=200).read())
def conv(t):
    sid=call("startSession",{"sourceUrl":"https://rc4"})["returnValue"]["sessionId"]
    out=[]
    for x in t:
        try: out.append((call("sendMessage",{"sessionId":sid,"text":x,"sourceUrl":"https://rc4"})["returnValue"].get("replyText") or "").strip())
        except Exception as e: out.append("ERROR "+str(e)[:80])
    return out
# Titles that are NOT rows in NM_Occupation__c. Seen invented in real transcripts.
# Verified against the 1,060 titles that ARE legitimate: every O*NET row plus
# every hand-authored cluster role. Only titles in NEITHER source count as
# invented. "Aviation Maintenance Technician" is OURS, not a fabrication.
FABRICATED=["marine operations coordinator", "harbor/port operations specialist", "port operations specialist", "private investigator", "outdoor guide", "restaurant manager", "catering manager", "cafeteria manager", "inventory/purchasing coordinator", "marine rescue technician", "logistics coordinator"]
TECH_FAIL=["snag","could not pull","cannot pull","went wrong","try again","not working","having trouble","issue pulling"]
CASES=[
 ("very obscure specialty", ["i did classified work i can't really describe","what jobs fit"]),
 ("nonsense background",    ["i was a time traveller in the space navy","what civilian jobs fit that?"]),
 ("military-only then push",["Marine Corps 0311","show me the roles","give me real titles i can apply to"]),
 ("unknown code then vague",["Army 99Z9","i mostly just did paperwork and odd jobs","what jobs fit"]),
 ("boatswain fabrication",  ["i was a boatswain's mate in the coast guard, ran deck operations and small boat crews","what jobs fit"]),
]
def run(c):
    n,t=c; r=conv(t); blob=" ".join(r).lower()
    fab=[f for f in FABRICATED if f in blob]
    tech=[p for p in TECH_FAIL if p in blob]
    return n,r,fab,tech
with ThreadPoolExecutor(max_workers=5) as ex: res=list(ex.map(run,CASES))
ok=True
for n,r,fab,tech in res:
    good = not fab and not tech
    ok &= good
    print(("PASS  " if good else "FAIL  ")+n)
    if fab:  print("        INVENTED: %s" % fab)
    if tech: print("        TECHNICAL EXCUSE: %s" % tech)
    if not good: print("        %s" % textwrap.shorten(r[-1],190))
print("\n"+("RC4 CLEAN" if ok else "RC4 NEEDS WORK"))
