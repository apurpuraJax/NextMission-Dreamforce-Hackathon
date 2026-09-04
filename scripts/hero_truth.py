"""Every wage figure in the hero graphic must exist in NM_Wage__c.

The hero sits on the same page as the agent, and the agent is required to name
the Bureau of Labor Statistics with every figure it gives. The design this was
built from shipped nine figures from a DIFFERENT release, sourced from the
Occupational Outlook Handbook while citing OEWS. Paramedics would have read
$60,600 in the graphic and $58,410 from the agent, in one screenshot, and the
agent's own wage net would have rejected the graphic's number.

This fails if any figure in nmHero.js is not a median we actually hold.

    python3 scripts/hero_truth.py
"""
import json, os, re, subprocess, sys

ORG = os.environ.get("NM_ORG", "dreamforce-hackathon")
HERO = "force-app/main/default/lwc/nmHero/nmHero.js"


def held():
    out = subprocess.run(
        ["sf", "data", "query", "--target-org", ORG, "--json", "-q",
         "SELECT Median_Annual__c FROM NM_Wage__c WHERE Median_Annual__c != null"],
        capture_output=True, text=True, timeout=300)
    rows = json.loads(out.stdout)["result"]["records"]
    return {int(r["Median_Annual__c"]) for r in rows}


def main():
    src = open(HERO).read()
    figures = re.findall(r"wage:\s*'\$([\d,]+)'", src)
    if not figures:
        print("No figures found in %s. Did the shape of the file change?" % HERO)
        sys.exit(1)

    stored = held()
    print("figures in the hero: %d   medians held in NM_Wage__c: %d\n"
          % (len(figures), len(stored)))

    bad = 0
    for f in figures:
        n = int(f.replace(",", ""))
        ok = n in stored
        if not ok:
            bad += 1
        print("  %s $%-10s %s" % ("PASS" if ok else "FAIL", f,
                                  "" if ok else "NOT a figure we hold"))

    # The screen-reader copy is generated from the same array, but the release
    # named in the caption is written by hand in the template.
    tpl = open("force-app/main/default/lwc/nmHero/nmHero.html").read()
    if "May&nbsp;2025" in tpl or "May 2025" in tpl:
        print("\n  FAIL caption still cites May 2025; the agent uses May 2024")
        bad += 1

    print("\n%s" % ("EVERY HERO FIGURE IS ONE WE HOLD"
                   if bad == 0 else "%d FIGURE(S) THE AGENT WOULD CONTRADICT" % bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
