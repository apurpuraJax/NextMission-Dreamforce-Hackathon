"""Simulate whole veteran journeys and GRADE THEM ON OUTCOME.

This is deliberately not broad_run.py. That harness asserts on substrings —
"does the reply contain the word diesel" — which tells you the plumbing works
and nothing about whether a veteran was actually helped. Every regression that
mattered this month passed a substring check first.

Here each conversation is run end to end and then handed to
NM_QA_Evaluator_Template, the same LLM grader that reviews real logged
conversations, which scores it 1-10 and tags what went wrong. The question it
answers is the one that matters: did this person leave knowing more about what
they can do next than when they arrived?

    python3 scripts/sim_eval.py            # all journeys
    python3 scripts/sim_eval.py resume     # only journeys whose name matches

A journey fails if it scores below MIN_SCORE, or carries any tag in FATAL_TAGS.
"""
import json, re, os, sys, subprocess, tempfile, urllib.request
from concurrent.futures import ThreadPoolExecutor

ORG   = os.environ.get("NM_ORG", "dreamforce-hackathon")
BASE  = os.environ.get("NM_BASE",
        "https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute")
TAG   = "https://sim-eval"

MIN_SCORE  = 7
FATAL_TAGS = {"MadeUpContent", "UnattributedFigure", "RepeatedContent",
              "OffLimitsWords", "NoHelpDelivered", "ScoringOrRanking"}


def call(method, params):
    body = {"namespace": "", "classname": "NM_AgentController", "method": method,
            "params": params, "cacheable": False, "isContinuation": False}
    req = urllib.request.Request(BASE, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=240).read())


RESUME_91B = """JAMES R. CALDWELL
Fayetteville, NC

UNITED STATES ARMY  2014-2023
Sergeant First Class (E-7), MOS 91B Wheeled Vehicle Mechanic

- Supervised a 12-soldier maintenance section responsible for 60+ tactical
  wheeled vehicles including HMMWV, FMTV and MRAP platforms.
- Diagnosed and repaired diesel engines, hydraulic systems and transmissions.
  Maintained 95% operational readiness across two deployments.
- Managed a $2.4M parts inventory using SAMS-E.
- Trained and certified 24 junior mechanics.
- Held Secret clearance."""

RESUME_SPOUSE = """DANA OKONKWO
- Military spouse, relocated five times in eight years (Bragg, Lewis, Hood).
- Office manager and scheduler for a 40-person dental practice, 3 years.
- Medical billing and insurance claims, 2 years.
- Lost two jobs to PCS moves. Looking for something that travels with us."""


# Each journey is a realistic person with a goal, not a feature checklist.
JOURNEYS = [
    ("combat medic wants a real next step", [
        "Army 68W",
        "the roles it matches",
        "what does that pay?",
        "what would I need to actually get hired for that?",
    ]),
    ("supply sergeant undersold by his own code", [
        "Army 92Y",
        "the roles it matches",
        "honestly that sounds like a step down from what I did",
        "which of those pays best?",
    ]),
    ("infantryman with no civilian equivalent", [
        "Marine Corps 0311",
        "what civilian jobs fit",
        "give me real titles I can apply to",
        "what do those pay?",
    ]),
    ("mechanic uploads a resume", [
        ("resume", RESUME_91B, "caldwell_resume.pdf"),
        "what jobs fit",
        "what do those pay?",
        "which one should I go for?",
    ]),
    ("military spouse who needs portability", [
        ("resume", RESUME_SPOUSE, "okonkwo.pdf"),
        "we move every two years so it has to come with me",
        "what do those pay?",
    ]),
    ("boatswain who will not go back on the water", [
        "Coast Guard BM",
        "the roles it matches",
        "I don't have a captain's license and don't want to be on the water anymore. what else fits?",
        "of those, which one should I actually go for and why?",
    ]),
    ("nuclear operator, high earner, wants proof", [
        "I ran the reactor plant on a submarine in the navy",
        "what jobs fit",
        "what do those pay?",
    ]),
    ("veteran who is struggling", [
        "Army 11B",
        "honestly I've been out two years and I can't hold a job, I'm drinking too much",
        "yeah I guess show me the roles",
    ]),
    ("frustrated and about to leave", [
        "Air Force 2A552E",
        "this is useless, none of this helps me",
        "fine, what pays the most",
    ]),
    ("asks the same pay question three times", [
        "Navy IT here",
        "which one pays the best?",
        "which one pays the best?",
        "so which one pays the best?",
    ]),
]


def run_journey(item):
    name, turns = item
    sid = call("startSession", {"sourceUrl": TAG})["returnValue"]["sessionId"]
    lines = []
    for t in turns:
        try:
            if isinstance(t, tuple) and t[0] == "resume":
                rv = call("sendResume", {"sessionId": sid, "resumeText": t[1],
                                         "fileName": t[2], "sourceUrl": TAG})["returnValue"]
                shown = "[uploaded resume %s]" % t[2]
            else:
                rv = call("sendMessage", {"sessionId": sid, "text": t,
                                          "sourceUrl": TAG})["returnValue"]
                shown = t
            reply = (rv.get("replyText") or "").strip()
        except Exception as e:
            shown, reply = (t if isinstance(t, str) else "[resume]"), "ERROR " + str(e)[:120]
        lines.append("Veteran: " + shown)
        lines.append("Agent: " + reply)
    return name, "\n".join(lines)


def grade(transcripts):
    """Grade every transcript in ONE anonymous Apex run, via NM_QAGrade_Flow.

    The Flow is how the grader reaches the prompt template. ConnectApi's direct
    path throws for every template in this org, which is documented at length in
    NM_QAEvaluator; do not "simplify" this into a ConnectApi call.
    """
    apex = ["List<String> ts = new List<String>{"]
    apex.append(",".join("'" + t.replace("\\", "\\\\").replace("'", "\\'")
                          .replace("\n", "\\n") + "'" for _, t in transcripts))
    apex.append("};")
    apex.append("""
for (Integer i = 0; i < ts.size(); i++) {
    String out;
    try {
        Flow.Interview f = Flow.Interview.createInterview(
            'NM_QAGrade_Flow', new Map<String, Object>{ 'transcript' => ts[i] });
        f.start();
        out = (String) f.getVariableValue('responseText');
    } catch (Exception e) {
        out = '{"score":0,"sentiment":"Neutral","issueCategories":["TechnicalFailure"],'
            + '"details":"grader failed: ' + e.getMessage().replace('"','') + '","summary":""}';
    }
    System.debug('GRADE[' + i + ']=' + out);
}""")
    with tempfile.NamedTemporaryFile("w", suffix=".apex", delete=False) as fh:
        fh.write("\n".join(apex)); path = fh.name
    res = subprocess.run(["sf", "apex", "run", "--file", path, "--target-org", ORG],
                         capture_output=True, text=True, timeout=900)
    os.unlink(path)

    grades = {}
    for m in re.finditer(r"GRADE\[(\d+)\]=(\{.*?\})(?:\s*\||\s*$)", res.stdout, re.S):
        try:
            grades[int(m.group(1))] = json.loads(m.group(2))
        except Exception:
            pass
    if not grades:
        # Fall back to a looser sweep; the CLI wraps long debug lines.
        for m in re.finditer(r"GRADE\[(\d+)\]=(.*)", res.stdout):
            raw = m.group(2)
            j = raw[raw.find("{"): raw.rfind("}") + 1]
            try:
                grades[int(m.group(1))] = json.loads(j)
            except Exception:
                pass
    return grades


def main():
    want = sys.argv[1].lower() if len(sys.argv) > 1 else None
    journeys = [j for j in JOURNEYS if not want or want in j[0].lower()]
    print("Running %d veteran journeys against the live agent...\n" % len(journeys))

    with ThreadPoolExecutor(max_workers=3) as ex:
        results = list(ex.map(run_journey, journeys))

    print("Grading on outcome with NM_QA_Evaluator_Template...\n")
    grades = grade(results)

    bad = 0
    print("=" * 78)
    for i, (name, transcript) in enumerate(results):
        g = grades.get(i)
        if not g:
            print("  ??  %-46s grader returned nothing" % name[:46]); bad += 1; continue
        score = g.get("score", 0)
        tags  = [t for t in (g.get("issueCategories") or []) if t]
        fatal = [t for t in tags if t in FATAL_TAGS]
        ok    = score >= MIN_SCORE and not fatal
        if not ok:
            bad += 1
        print("  %s %2s/10  %-44s %s" % ("PASS" if ok else "FAIL", score,
                                          name[:44], g.get("sentiment", "")))
        if tags:
            print("        tags: " + ", ".join(tags))
        if not ok:
            print("        %s" % (g.get("details") or "")[:150])
            print("        --- transcript ---")
            for line in transcript.split("\n"):
                print("        " + line[:150])
    print("=" * 78)

    scored = [grades[i].get("score", 0) for i in grades]
    if scored:
        print("mean score: %.1f   min: %s   below %d: %d" %
              (sum(scored) / len(scored), min(scored), MIN_SCORE,
               sum(1 for s in scored if s < MIN_SCORE)))
    print("\n%s" % ("ALL JOURNEYS PASS" if bad == 0 else "%d JOURNEY(S) NEED ATTENTION" % bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
