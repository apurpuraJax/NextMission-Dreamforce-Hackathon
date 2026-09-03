"""Every dollar figure the agent shows must exist in NM_Wage__c.

Written after finding the agent inventing BLS-looking numbers that read
perfectly: Warehouse Operations Manager at $98,560 when the stored figure is
$102,010, Supply Chain Analyst at $67,190 against a real $80,880. Every figure
in that reply was fabricated and every other check passed it, because they only
asked whether a dollar sign and a source were present.

    python3 scripts/wage_truth.py [runs]
"""
import json, re, subprocess, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = "https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute"
ORG  = "dreamforce-hackathon"

def call(m, p):
    b = {"namespace":"","classname":"NM_AgentController","method":m,
         "params":p,"cacheable":False,"isContinuation":False}
    r = urllib.request.Request(BASE, data=json.dumps(b).encode(),
                               headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(r, timeout=240).read())

def held_figures():
    q = ("SELECT Median_Annual__c, Pct10_Annual__c, Pct90_Annual__c, "
         "Total_Employment__c FROM NM_Wage__c")
    out = subprocess.run(["sf","data","query","--target-org",ORG,"-q",q,"--json"],
                         capture_output=True, text=True, timeout=600)
    rows = json.loads(out.stdout)["result"]["records"]
    vals = set()
    for x in rows:
        for k in ("Median_Annual__c","Pct10_Annual__c","Pct90_Annual__c","Total_Employment__c"):
            if x.get(k) is not None:
                vals.add(int(x[k]))
    return vals

# Conversations that end in a pay question, across both matching paths.
CASES = [
 ("coded, rich mapping",   ["Army 68W","the roles it matches","what do those pay?"]),
 ("coded, thin row",       ["Army 92Y","the roles it matches","what do those pay?"]),
 ("coded, residual bucket",["Army 25B","the roles it matches","what do those pay?"]),
 ("widened past the code", ["Coast Guard BM","the roles it matches",
                            "I don't have a captain's license and don't want to be on the water anymore. what else fits?",
                            "what do those pay?"]),
 ("free text",             ["i fixed helicopters in the marines","what jobs fit","what do those pay?"]),
 ("ranking by pay",        ["Army 92Y","the roles it matches","which one pays the most?"]),
 ("military-only code",    ["Marine Corps 0311","what civilian jobs fit","what do those pay?"]),
]

def run(case):
    name, turns = case
    sid = call("startSession", {"sourceUrl":"https://wt"})["returnValue"]["sessionId"]
    replies = []
    for t in turns:
        try:
            replies.append((call("sendMessage", {"sessionId":sid,"text":t,
                "sourceUrl":"https://wt"})["returnValue"].get("replyText") or "").strip())
        except Exception as e:
            replies.append("ERROR " + str(e)[:80])
    return name, replies

def main():
    runs = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    held = held_figures()
    print("figures held in NM_Wage__c: %d\n" % len(held))
    bad = 0
    for n in range(runs):
        if runs > 1:
            print("--- pass %d ---" % (n + 1))
        with ThreadPoolExecutor(max_workers=3) as ex:
            results = list(ex.map(run, CASES))
        for name, replies in results:
            figs = set()
            for r in replies:
                figs |= {int(x.replace(",", ""))
                         for x in re.findall(r"\$\s?([0-9][0-9,]{2,})", r)}
            invented = sorted(f for f in figs if f not in held)
            ok = not invented
            if not ok:
                bad += 1
            print("  %s %-24s %2d figures%s" % (
                "PASS" if ok else "FAIL", name, len(figs),
                "" if ok else "   INVENTED: " + ", ".join("$%s" % f"{f:,}" for f in invented)))
            if not ok:
                for r in replies:
                    if any(str(f) in r.replace(",", "") for f in invented):
                        print("        " + r[:300])
        time.sleep(2)
    print("\n%s" % ("EVERY FIGURE IS REAL" if bad == 0
                    else "%d CONVERSATION(S) CONTAINED AN INVENTED FIGURE" % bad))
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
