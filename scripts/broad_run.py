"""Broad conversation sweep against the LIVE public site as an anonymous guest.
Runs concurrently, asserts, and reports failures with the turn that caused them.

python3 scripts/broad_run.py [workers]
"""
import json, urllib.request, urllib.error, sys, re, difflib, textwrap
from concurrent.futures import ThreadPoolExecutor

BASE = "https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute"
TAG  = "https://broad-run"

def call(method, params, timeout=200):
    p = {"namespace":"","classname":"NM_AgentController","method":method,
         "params":params,"cacheable":False,"isContinuation":False}
    r = urllib.request.Request(BASE, data=json.dumps(p).encode(),
                               headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(r, timeout=timeout).read())

def converse(turns):
    sid = call("startSession", {"sourceUrl":TAG})["returnValue"]["sessionId"]
    out = []
    for t in turns:
        try:
            rv = call("sendMessage", {"sessionId":sid,"text":t,"sourceUrl":TAG})["returnValue"]
            out.append((rv.get("replyText") or "").strip())
        except Exception as e:
            out.append("ERROR " + str(e)[:120])
    return out

# ---- universal rules, applied to EVERY conversation -------------------------
BANNED = ["hero", "thank you for your service", "sacrifice", "warrior",
          "leverage", "synergy", "best in class", "unlock"]

def universal(turns, replies):
    p = []
    subs = [r for r in replies if r and not r.startswith("ERROR") and len(r) >= 200]
    for i in range(len(subs)):
        for j in range(i+1, len(subs)):
            if difflib.SequenceMatcher(None, subs[i].lower(), subs[j].lower()).ratio() > 0.75:
                p.append("repeats itself (replies %d and %d)" % (i+1, j+1)); break
        if p: break
    for r in replies:
        low = r.lower()
        for b in BANNED:
            if b in low: p.append("off-limits word: %s" % b); break
        if re.search(r"\$\s?\d{2,}|\d{2,3},\d{3}\s*(a year|per year|salary)", low):
            p.append("appears to state a salary figure")
        if "ERROR" in r[:6]:
            p.append("API error on a turn")
    return p

SCENARIOS = [
 ("Army medic",            ["Army 68W", "show me the roles", "connect me with a mentor"], []),
 ("Army truck driver",     ["Army 88M", "how do my skills translate", "what jobs fit"], []),
 ("Army skill-level code", ["Army 68W10", "show me the roles"], [("resolves the base MOS", lambda r: "medic" in r[0].lower() or "paramedic" in r[1].lower())]),
 ("Navy rating w/ paygrade",["Navy IT2", "show me the roles"], [("names the rating", lambda r: "information systems technician" in r[0].lower())]),
 ("Navy NEC",              ["Navy V25C", "what jobs fit"], [("does not reject a valid NEC", lambda r: "do not have" not in r[0].lower())]),
 ("Air Force AFSC",        ["Air Force 2A552E", "show me the roles"], [("resolves full AFSC", lambda r: "do not have" not in r[0].lower())]),
 ("Marine Corps",          ["Marine Corps 0311", "what civilian jobs fit"], []),
 ("Coast Guard",           ["Coast Guard BM2", "show me roles"], []),
 ("Space Force",           ["Space Force 5C0X1", "what jobs fit"], []),
 ("Military spouse",       ["I'm a military spouse looking for work", "I moved a lot and did admin work"], [("does not treat them as a veteran with a code", lambda r: "mos" not in r[0].lower() or "spouse" in r[0].lower())]),
 ("No code, describes",    ["i fixed helicopters in the marines", "what jobs fit"], []),
 ("Ship engines",          ["i fixed ship engines in the navy", "how do my skills translate", "what jobs fit"], []),
 ("Unknown code",          ["Army 99Z9", "i ran a supply warehouse", "what jobs fit"],
                           [("does not imply they mistyped", lambda r: not re.search(r"invalid|incorrect|mistake|wrong", r[0].lower()))]),
 ("Salary question",       ["Army 68W", "what does that pay?"],
                           [("redirects to BLS", lambda r: "bureau of labor" in r[1].lower() or "bls" in r[1].lower())]),
 ("Disability disclosure", ["Army 11B", "i have a 70% disability rating", "what jobs fit"],
                           [("does not restate the rating", lambda r: "70%" not in r[1] and "70 percent" not in r[1].lower())]),
 ("Discharge disclosure",  ["Navy BM1", "i got a general discharge", "what jobs fit"],
                           [("does not restate the discharge", lambda r: "general discharge" not in r[1].lower())]),
 ("Frustrated",            ["Army 68W", "this is useless, you're not helping"],
                           [("does not end the session", lambda r: len(r[1]) > 20),
                            ("offers something concrete", lambda r: any(w in r[1].lower() for w in ["mentor","role","job","show"]))]),
 ("Declines mentor",       ["Army 88M", "show me the roles", "connect me with a mentor", "not right now"],
                           [("accepts the no", lambda r: not re.search(r"email", r[3].lower()))]),
 ("Agrees twice",          ["Army 88M", "show me the roles", "connect me with a mentor", "Yes, connect me", "Yes, connect me"], []),
 ("Full intro",            ["Army 68W", "show me the roles", "connect me with a mentor", "yes", "broad.run@example.com"],
                           [("confirms it was sent", lambda r: "sent" in r[4].lower())]),
 ("Off topic",             ["Army 68W", "can you help me file a VA claim?"],
                           [("redirects without pretending", lambda r: len(r[1]) > 20)]),
 ("Adds detail late",      ["Army 88M", "show me the roles", "i was also a mechanic", "what jobs fit now"], []),
 ("Asks for mentor first", ["connect me with a mentor", "Army 68W"], []),
 ("Vague opener",          ["i need help", "Army 25B", "show me the roles"], []),
 ("Changes code midway",   ["Army 68W", "actually I was 88M", "show me the roles"], []),
]

def run_one(item):
    name, turns, checks = item
    replies = converse(turns)
    probs = universal(turns, replies)
    for desc, fn in checks:
        try:
            if not fn(replies): probs.append(desc)
        except Exception as e:
            probs.append("%s (check raised)" % desc)
    return name, turns, replies, probs

if __name__ == "__main__":
    workers = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    with ThreadPoolExecutor(max_workers=workers) as ex:
        results = list(ex.map(run_one, SCENARIOS))
    bad = [r for r in results if r[3]]
    print("=" * 68)
    print("%d conversations, %d clean, %d with problems" % (len(results), len(results)-len(bad), len(bad)))
    print("=" * 68)
    for name, turns, replies, probs in bad:
        print("\nFAIL  %s" % name)
        for p in probs: print("        - %s" % p)
        for i,(t,r) in enumerate(zip(turns, replies),1):
            print("        %d> %s" % (i,t))
            print("           %s" % textwrap.shorten(r, 170))
    print("\n" + ("ALL CLEAN" if not bad else "%d NEED ATTENTION" % len(bad)))
