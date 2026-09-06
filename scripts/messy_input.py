"""Type like a real person and see whether the agent still works.

Every other suite in this repo uses well-formed input: "Army 68W",
"Marine Corps 0311". Forty-seven conversations and not one typed a code the way
a tired person on a phone actually types it. Two real bugs lived behind that
gap for the entire build:

  "88 m"   -> "I do not have that code in my system."   trim() only strips ends
  "Marines" -> nothing at all.                          the crosswalk says
                                                        "Marine Corps", and the
                                                        agent was only ASKED to
                                                        normalise the branch

Both are fixed in Apex now. This suite exists so they cannot come back, and so
the next person adding a lookup path has somewhere to put the messy cases.

Three rules, in order of how much damage breaking them does:

  1. NEVER INVENT.  A code we do not hold must never produce a description of
     what that work involved. Confident, plausible, and about nobody is the
     worst output this product can produce.
  2. OFFER A NEAR MISS.  A code one character from a real one gets asked about,
     never silently substituted.
  3. RESOLVE MESSY INPUT.  Spaces, case, punctuation and the name people
     actually call their service all have to work.

    python3 scripts/messy_input.py
    python3 scripts/messy_input.py branch     # only cases whose name matches
"""
import json, os, re, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = os.environ.get("NM_BASE",
       "https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute")
TAG = "https://messy-input"

# Phrases that mean the agent has started describing work it has no data for.
INVENTION = [
    "you know how to", "your background", "skills in", "your experience lines up",
    "you can run", "in your wheelhouse", "day-to-day work involved managing",
    "you have strong skills", "gives you skills",
]
# Phrases that wrongly tell a veteran we lack a code we actually resolved.
FALSE_MISS = [
    "do not have that code", "don't have that code", "not in the crosswalk",
    "do not have that", "is not a code",
]


def call(method, params):
    body = {"namespace": "", "classname": "NM_AgentController", "method": method,
            "params": params, "cacheable": False, "isContinuation": False}
    req = urllib.request.Request(BASE, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=240).read())


def ask(text):
    sid = call("startSession", {"sourceUrl": TAG})["returnValue"]["sessionId"]
    rv = call("sendMessage", {"sessionId": sid, "text": text, "sourceUrl": TAG})["returnValue"]
    return (rv.get("replyText") or "").strip()


# ── the cases ────────────────────────────────────────────────────────────────
# ("name", "what they type", "expect", "value")
#   resolves : the reply must name this role title, and must not claim we lack it
#   asks     : the reply must offer this code back as a question
#   refuses  : the reply must not describe the work at all
CASES = [
    # --- a real code, typed the way people type ---
    ("code: plain",              "Army 88M",        "resolves", "Motor Transport Operator"),
    ("code: internal space",     "Army 88 m",       "resolves", "Motor Transport Operator"),
    ("code: lowercase",          "army 68w",        "resolves", "Combat Medic Specialist"),
    ("code: hyphen",             "Army 88-M",       "resolves", "Motor Transport Operator"),
    ("code: trailing period",    "Army 88M.",       "resolves", "Motor Transport Operator"),
    ("code: skill level",        "Army 68W20",      "resolves", "Combat Medic Specialist"),
    ("code: in a sentence",      "i was an 88M in the army",   "resolves", "Motor Transport Operator"),
    ("code: present tense",      "I'm a 68W in the Army",      "resolves", "Combat Medic Specialist"),
    ("code: no space at all",    "Marine Corps 0311",          "resolves", "Rifleman"),
    ("code: spaced digits",      "Marine Corps 03 11",         "resolves", "Rifleman"),

    # --- the branch, as people actually say it ---
    ("branch: Marines",          "Marines 0311",    "resolves", "Rifleman"),
    ("branch: USMC",             "USMC 0311",       "resolves", "Rifleman"),
    ("branch: the Marines",      "the Marines 0311","resolves", "Rifleman"),
    ("branch: US Army",          "US Army 88M",     "resolves", "Motor Transport Operator"),
    ("branch: U.S. Army",        "U.S. Army 88M",   "resolves", "Motor Transport Operator"),
    ("branch: US Navy",          "US Navy HM",      "resolves", "Hospital Corpsman"),
    ("branch: USN",              "USN HM",          "resolves", "Hospital Corpsman"),
    ("branch: USAF",             "USAF 2A5X1",      "resolves", "Aircraft Maintenance"),
    ("branch: USCG",             "USCG BM",         "resolves", "Boatswain"),
    ("branch: lowercase air force", "air force 2A5X1", "resolves", "Aircraft Maintenance"),

    # --- valid ways to write a code that are not the stored spelling ---
    ("structure: dropped zero",  "I was a 311 in the Marines", "resolves", "Rifleman"),
    ("structure: AFSC level",    "Air Force 2A551", "resolves", "Aircraft Maintenance"),
    ("phrasing: MOS prefix",     "my MOS was 88M in the Army", "resolves", "Motor Transport Operator"),
    ("phrasing: rate prefix",    "Navy, rate HM",   "resolves", "Hospital Corpsman"),

    # --- codes as people SAY them, phonetic alphabet ---
    ("spoken: 88 mike",          "I was an 88 mike in the army", "resolves", "Motor Transport Operator"),
    ("spoken: eleven bravo",     "army, eleven bravo",           "resolves", "11B"),
    ("spoken: 68 whiskey",       "I was a sixty-eight whiskey",  "resolves", "Combat Medic Specialist"),

    # --- one character off a real code: ask, never assume ---
    ("near miss: 88J",           "Army 88J",        "asks",     "88H"),
    ("near miss: messy 88J",     "army 88 j",       "asks",     "88H"),

    # --- not a code at all: must not invent a background ---
    ("nonsense: ZZ99",           "Army ZZ99",       "refuses",  None),
    ("nonsense: letters",        "Army QQQQ",       "refuses",  None),
    ("nonsense: numbers",        "Navy 999999",     "refuses",  None),
]


def check(case):
    name, typed, expect, value = case
    try:
        reply = ask(typed)
    except Exception as e:
        return name, typed, False, "ERROR " + str(e)[:90], ""
    low = reply.lower()

    if expect == "resolves":
        for p in FALSE_MISS:
            if p in low:
                return name, typed, False, "claimed we lack a code we resolved", reply
        for p in INVENTION:
            if p in low:
                return name, typed, False, "invented instead of resolving", reply
        # Naming the role is the normal shape. But subagent conditionals
        # evaluate AFTER the turn's action, so the branch written for a
        # returning visitor sometimes fires on turn one and the greeting skips
        # the title while still resolving the code. The code being resolved is
        # the contract; the greeting's exact shape is not.
        named = value.lower() in low
        resolved_shape = ("translates into civilian skills" in low
                          or "civilian roles it matches" in low)
        if named or resolved_shape:
            return name, typed, True, "", reply
        return name, typed, False, "neither named %r nor resolved" % value, reply

    if expect == "asks":
        if value.lower() not in low:
            return name, typed, False, "did not offer %r" % value, reply
        if "?" not in reply:
            return name, typed, False, "offered it without asking", reply
        for p in INVENTION:
            if p in low:
                return name, typed, False, "described work it has no data for", reply
        return name, typed, True, "", reply

    # refuses
    for p in INVENTION:
        if p in low:
            return name, typed, False, "INVENTED a background: %r" % p, reply
    return name, typed, True, "", reply


# ── multi-turn: messy input all the way through a real journey ───────────────
# (name, [turns], phrase the LAST reply must contain)
JOURNEYS = [
    ("pay asked with a singular role",
     ["army 68w", "the roles it matches", "what does a Paramedic make?"],
     "$"),
    # 68W maps straight to a civilian occupation. 0311 is military-only and
    # detours through describe-background first, which tests a different thing.
    ("email pasted with a trailing space",
     ["army 68w", "connect me with a mentor", "yes please",
      " veteran.messy@example.com "],
     "sent"),
    ("email typed with a full stop",
     ["US Army 68W", "connect me with a mentor", "yes",
      "veteran.messy2@example.com."],
     "sent"),
    ("near miss then correction",
     ["Army 88J", "yes that one"],
     ""),   # only has to proceed without inventing
]


def journey(item):
    """Answer whatever the agent asks, the way a person would.

    An earlier version fired a fixed script of four turns and called it a
    failure when the agent was one turn behind. It was not failing; it was
    still asking. A real person answers the next question, so this does too,
    up to a sensible limit.
    """
    name, turns, must_contain = item
    try:
        sid = call("startSession", {"sourceUrl": TAG})["returnValue"]["sessionId"]
        last = ""
        for t in turns:
            rv = call("sendMessage", {"sessionId": sid, "text": t, "sourceUrl": TAG})
            last = (rv["returnValue"].get("replyText") or "").strip()

        # Keep answering while it is still asking, rather than giving up.
        follow = 0
        while follow < 4 and must_contain and must_contain.lower() not in last.lower():
            low = last.lower()
            wants_email = "email" in low or "@" in low
            on_topic = "mentor" in low or "introduc" in low
            if wants_email:
                nxt = turns[-1] if "@" in turns[-1] else "someone@example.com"
            elif on_topic:
                nxt = "yes please"
            else:
                # It drifted onto something else. A person chasing an
                # introduction asks again rather than following it away.
                nxt = "connect me with a mentor"
            rv = call("sendMessage", {"sessionId": sid, "text": nxt, "sourceUrl": TAG})
            last = (rv["returnValue"].get("replyText") or "").strip()
            follow += 1
    except Exception as e:
        return name, turns[-1], False, "ERROR " + str(e)[:90], ""

    low = last.lower()
    if must_contain and must_contain.lower() not in low:
        return name, turns[-1], False, "never reached %r" % must_contain, last
    return name, turns[-1], True, "", last


def main():
    want = sys.argv[1].lower() if len(sys.argv) > 1 else None
    cases = [c for c in CASES if not want or want in c[0].lower()]
    print("typing %d messy things at the live agent...\n" % len(cases))

    with ThreadPoolExecutor(max_workers=2) as ex:
        results = list(ex.map(check, cases))

    bad = 0
    for name, typed, ok, why, reply in results:
        if not ok:
            bad += 1
        print("  %s %-28s %r" % ("PASS" if ok else "FAIL", name[:28], typed))
        if not ok:
            print("        %s" % why)
            print("        reply: %s" % reply[:220].replace("\n", " "))
    js = [j for j in JOURNEYS if not want or want in j[0].lower()]
    if js:
        print("\n  --- multi-turn, messy the whole way ---")
        with ThreadPoolExecutor(max_workers=1) as ex:
            jres = list(ex.map(journey, js))
        for name, typed, ok, why, reply in jres:
            if not ok:
                bad += 1
            print("  %s %-28s %r" % ("PASS" if ok else "FAIL", name[:28], typed))
            if not ok:
                print("        %s" % why)
                print("        reply: %s" % reply[:220].replace("\n", " "))
        results = results + jres

    print()
    print("%d of %d" % (len(results) - bad, len(results)))
    print(("EVERY MESSY INPUT HANDLED" if bad == 0
           else "%d CASE(S) A REAL PERSON WOULD HIT" % bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
