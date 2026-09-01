"""Scenario suite for Next Mission. Asserts, rather than printing for a human to
eyeball. Every scenario runs against the LIVE public site as an anonymous guest."""
import json, urllib.request, urllib.error, sys, re, difflib, textwrap

BASE = "https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute"

def call(method, params, timeout=180):
    p = {"namespace":"","classname":"NM_AgentController","method":method,
         "params":params,"cacheable":False,"isContinuation":False}
    r = urllib.request.Request(BASE, data=json.dumps(p).encode(),
                               headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(r, timeout=timeout).read())

def run(name, turns, checks, repeat=1):
    """repeat > 1 for anything the model can get right by luck. A mentor being
    re-described slipped through a single passing run and was then reported from
    real use. Conversation bugs are frequently flaky; run them more than once."""
    if repeat > 1:
        allok = True
        for i in range(repeat):
            allok &= _once("%s [%d/%d]" % (name, i+1, repeat), turns, checks)
        return allok
    return _once(name, turns, checks)

def _once(name, turns, checks):
    sid = call("startSession", {"sourceUrl":"https://scenario"})["returnValue"]["sessionId"]
    replies = []
    for t in turns:
        try:
            rv = call("sendMessage", {"sessionId":sid,"text":t,"sourceUrl":"https://scenario"})["returnValue"]
            replies.append((rv.get("replyText") or "").strip())
        except Exception as e:
            replies.append("ERROR " + str(e))
    fails = []
    for desc, fn in checks:
        try:
            if not fn(replies): fails.append(desc)
        except Exception as e:
            fails.append("%s (check raised %s)" % (desc, e))
    print(("PASS  " if not fails else "FAIL  ") + name)
    for f in fails: print("        - " + f)
    if fails:
        for i,(t,r) in enumerate(zip(turns,replies),1):
            print("        %d> %s" % (i, t))
            print("           %s" % textwrap.shorten(r, 150))
    return not fails

def similar(a, b):
    return difflib.SequenceMatcher(None, a.lower(), b.lower()).ratio()

def no_repeats(threshold=0.75, min_len=200):
    """No two SUBSTANTIVE agent replies may be near-identical. This is the check
    that catches the mentor loop and the repeated skills framing.

    Short replies are excluded deliberately: re-asking for an email address the
    veteran has not given yet is correct behaviour, not repetition. The bug this
    guards against is re-delivering CONTENT they have already read."""
    def f(replies):
        real = [r for r in replies
                if r and not r.startswith("ERROR") and len(r) >= min_len]
        for i in range(len(real)):
            for j in range(i+1, len(real)):
                if similar(real[i], real[j]) > threshold:
                    raise AssertionError("turns %d and %d are %.0f%% identical"
                                         % (i+1, j+1, similar(real[i], real[j])*100))
        return True
    return f

def contains(idx, *words):
    return lambda r: any(w.lower() in r[idx].lower() for w in words)

def lacks(idx, *words):
    return lambda r: not any(w.lower() in r[idx].lower() for w in words)

ok = True

ok &= run("Navy IT2 resolves through the crosswalk, not the describe path",
    ["Navy IT2"],
    [("names Information Systems Technician", contains(0, "Information Systems Technician")),
     ("does not claim the code is unknown", lacks(0, "do not have", "don't have", "not have a direct match"))])

def names_a_mentor(idx):
    """A capitalised name plus a role/employer. Consent to an introduction is not
    meaningful unless the veteran has been told who the person is."""
    def f(replies):
        r = replies[idx]
        return bool(re.search(r"\b[A-Z][a-z]+ [A-Z]\.", r)) and (" at " in r or "is a " in r or "is an " in r)
    return f

ok &= run("A mentor is named BEFORE any email address is requested",
    ["Army 88M", "show me the roles", "connect me with a mentor"],
    [("names the mentor with role and employer", names_a_mentor(2)),
     ("does not ask for an email before naming anyone", lacks(2, "email address", "your email"))],
    repeat=3)

ok &= run("Mentor consent does not loop when the veteran agrees twice",
    ["Army 88M", "show me the roles", "connect me with a mentor", "Yes, connect me", "Yes, connect me"],
    [("no two replies are near-identical", no_repeats()),
     ("asks for an email once the mentor is known", contains(3, "email")),
     ("does not re-describe the mentor on the repeat", lacks(4, "employer", "started as", "moved into"))],
    repeat=3)

ok &= run("Describe path does not repeat the same framing",
    ["i fixed ship engines", "Let me add something", "i was a marksman", "How do my skills translate?"],
    [("no two replies are near-identical", no_repeats())])

ok &= run("Full journey to a real introduction",
    ["Army 68W", "show me the roles", "connect me with a mentor", "yes please",
     "scenario.test@example.com"],
    [("no two replies are near-identical", no_repeats()),
     ("confirms the introduction was sent", contains(4, "sent", "introduction"))])

print("\nSUITE " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
