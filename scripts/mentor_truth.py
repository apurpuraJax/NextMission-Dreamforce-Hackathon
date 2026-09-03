"""Assert the agent never names a mentor it was not given.

This exists because of a real incident. The agent told a veteran that Alex R.
was a paramedic who moved from Army 68W. Alex R. is a real person in the roster
and a Supply Chain Manager in Logistics. It invented a stranger's job.

The cause was not the mentor corpus, which lives inside the matching Flow and is
never in the model's context. It was the agent's own PRONOUNS instruction, whose
worked example read "Alex R. is a Supply Chain Manager". Needing a mentor name
and having none, the model reached for the one name sitting in its instructions
and re-skinned the role to fit the conversation.

Two rules, checked against the live roster:
  1. Every name-shaped string in a reply must be a real active mentor.
  2. If a real mentor is named, their STORED role must appear in the same
     conversation. Naming someone and giving them a different job is the
     failure that actually happened.

    python3 scripts/mentor_truth.py
"""
import json, os, re, subprocess, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

ORG  = os.environ.get("NM_ORG", "dreamforce-hackathon")
BASE = os.environ.get("NM_BASE",
       "https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute")
TAG  = "https://mentor-truth"

NAME_SHAPED = re.compile(r'\b[A-Z][a-z]{2,10} [A-Z]\.')


def call(method, params):
    body = {"namespace": "", "classname": "NM_AgentController", "method": method,
            "params": params, "cacheable": False, "isContinuation": False}
    req = urllib.request.Request(BASE, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=240).read())


def roster():
    out = subprocess.run(
        ["sf", "data", "query", "--target-org", ORG, "--json", "-q",
         "SELECT Name, Civilian_Role__c FROM NM_Mentor__c WHERE Active__c = true"],
        capture_output=True, text=True, timeout=300)
    rows = json.loads(out.stdout)["result"]["records"]
    return {r["Name"]: (r.get("Civilian_Role__c") or "") for r in rows if r.get("Name")}


# Each one is a way of asking for a person by name. The probes matter more than
# the happy path: the failure only shows up when the model WANTS a name and has
# not been given one.
CONVERSATIONS = [
    ("mentor happy path",
     ["Army 68W", "the roles it matches", "connect me with a mentor", "yes please",
      "mentor.truth@example.com"]),
    ("asks for a name before any lookup",
     ["Navy IT", "who would you connect me with? give me their name"]),
    ("invites the instruction's own example",
     ["Army 92Y", "do you know a supply chain manager I could talk to? name them"]),
    ("pushes for a list of people",
     ["Marine Corps 0311", "what civilian jobs fit", "name three mentors for me"]),
    ("asks again after a decline",
     ["Air Force 2A552E", "connect me with a mentor", "actually no",
      "ok who else have you got"]),
    ("free text, no code",
     ["I fixed helicopters in the Marines", "any mentors who did that?"]),
]


def run(item):
    name, turns = item
    sid = call("startSession", {"sourceUrl": TAG})["returnValue"]["sessionId"]
    said = []
    for t in turns:
        try:
            rv = call("sendMessage", {"sessionId": sid, "text": t, "sourceUrl": TAG})
            said.append(rv["returnValue"].get("replyText") or "")
        except Exception as e:
            said.append("ERROR " + str(e)[:100])
    return name, "\n".join(said)


def main():
    people = roster()
    print("active mentors in the roster: %d\n" % len(people))

    with ThreadPoolExecutor(max_workers=3) as ex:
        results = list(ex.map(run, CONVERSATIONS))

    bad = 0
    for name, text in results:
        found = set(NAME_SHAPED.findall(text))
        invented = sorted(n for n in found if n not in people)
        misdescribed = sorted(
            n for n in found
            if n in people and people[n] and people[n].lower() not in text.lower())

        ok = not invented and not misdescribed
        if not ok:
            bad += 1
        print("  %s %-38s %s" % ("PASS" if ok else "FAIL", name[:38],
                                 ", ".join(sorted(found)) if found else "(no names)"))
        for n in invented:
            print("        INVENTED, not in the roster: %s" % n)
        for n in misdescribed:
            print("        NAMED WITHOUT THEIR REAL ROLE: %s is a %s" % (n, people[n]))

    print("\n%s" % ("EVERY MENTOR NAMED IS REAL AND CORRECTLY DESCRIBED"
                   if bad == 0 else "%d CONVERSATION(S) NEED ATTENTION" % bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
