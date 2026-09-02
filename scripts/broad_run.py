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

# ---- RELEVANCE ---------------------------------------------------------------
# The check that was missing. Every earlier sweep passed while a helicopter
# mechanic was offered Construction Project Manager and Heavy Equipment
# Operator, because nothing verified the answer was CORRECT, only that it was
# well-formed and non-repetitive. A confident wrong answer is worse than an
# unhelpful one, and it is exactly what a veteran would act on.

def relevant(*words):
    """At least one of these must appear somewhere in the conversation."""
    def f(replies):
        blob = " ".join(replies).lower()
        return any(w in blob for w in words)
    return f

def never(*words):
    """None of these may appear. Used to catch a whole wrong career field."""
    def f(replies):
        blob = " ".join(replies).lower()
        return not any(w in blob for w in words)
    return f

WRONG_FIELD = {
  "aviation":    ["construction project manager", "heavy equipment operator", "estimator"],
  "medical":     ["construction project manager", "heavy equipment operator", "truck driver"],
  "it":          ["construction project manager", "heavy equipment operator", "paramedic"],
  "driving":     ["paramedic", "air traffic controller", "avionics"],
}

# ---- universal rules, applied to EVERY conversation -------------------------
BANNED = ["hero", "thank you for your service", "sacrifice", "warrior",
          "leverage", "synergy", "best in class", "unlock"]

def universal(turns, replies):
    p = []
    # Only CONSECUTIVE, near-verbatim replies. Both real repetition bugs this
    # caught (Marine 0311, Coast Guard BM) were adjacent and almost identical.
    # Comparing every pair at 0.75 started firing on correct behaviour once
    # replies began carrying role lists AND wages: re-showing the same five
    # roles with pay added is a legitimate answer, not a stuck agent.
    subs = [r for r in replies if r and not r.startswith("ERROR") and len(r) >= 200]
    for i in range(len(subs) - 1):
        if difflib.SequenceMatcher(None, subs[i].lower(), subs[i+1].lower()).ratio() > 0.85:
            p.append("repeats itself (replies %d and %d)" % (i+1, i+2)); break
    for r in replies:
        low = r.lower()
        for b in BANNED:
            if b in low: p.append("off-limits word: %s" % b); break
        # NMDH-23. The agent HAS BLS wage data now, so a figure is not itself a
        # defect. An UNATTRIBUTED figure is: that is what invention looks like,
        # and it is what a veteran would screenshot and act on.
        if re.search(r"\$\s?\d{2,}|\d{2,3},\d{3}\s*(a year|per year|salary)", low):
            if not ("bureau of labor" in low or "bls" in low):
                p.append("states a pay figure without naming the source")
        if "ERROR" in r[:6]:
            p.append("API error on a turn")
    return p

SCENARIOS = [
 ("Army medic",            ["Army 68W", "show me the roles", "connect me with a mentor"],
                           [("offers medical roles", relevant("paramedic","emergency medical","medical")),
                            ("not a wrong career field", never(*WRONG_FIELD["medical"]))]),
 ("Army truck driver",     ["Army 88M", "how do my skills translate", "what jobs fit"],
                           [("offers driving roles", relevant("truck driver","tractor-trailer","driver")),
                            ("not a wrong career field", never(*WRONG_FIELD["driving"]))]),
 ("Army skill-level code", ["Army 68W10", "show me the roles"], [("resolves the base MOS", lambda r: "medic" in r[0].lower() or "paramedic" in r[1].lower())]),
 ("Navy rating w/ paygrade",["Navy IT2", "show me the roles"],
                           [("names the rating", lambda r: "information systems technician" in r[0].lower()),
                            ("offers IT roles", relevant("network","computer","systems administrator","information")),
                            ("NOT construction", never(*WRONG_FIELD["it"]))]),
 ("Navy NEC",              ["Navy V25C", "what jobs fit"], [("does not reject a valid NEC", lambda r: "do not have" not in r[0].lower())]),
 ("Air Force AFSC",        ["Air Force 2A552E", "show me the roles"], [("resolves full AFSC", lambda r: "do not have" not in r[0].lower())]),
 ("Marine Corps",          ["Marine Corps 0311", "what civilian jobs fit"], []),
 ("Coast Guard",           ["Coast Guard BM2", "show me roles"], []),
 ("Space Force",           ["Space Force 5C0X1", "what jobs fit"], []),
 ("Military spouse",       ["I'm a military spouse looking for work", "I moved a lot and did admin work"], [("does not treat them as a veteran with a code", lambda r: "mos" not in r[0].lower() or "spouse" in r[0].lower())]),
 ("No code, describes",    ["i fixed helicopters in the marines", "what jobs fit"],
                           [("offers aviation roles", relevant("aircraft","aviation","avionics","a&p")),
                            ("NOT construction", never(*WRONG_FIELD["aviation"]))]),
 ("Ship engines",          ["i fixed ship engines in the navy", "how do my skills translate", "what jobs fit"],
                           [("offers mechanical or marine roles", relevant("mechanic","engine","marine","machinist","maintenance","technician"))]),
 # 99Z9 used to be unknown and now resolves, so this moved to a code that
 # genuinely is not in the crosswalk. A scenario that stops testing what it
 # was written for is worse than no scenario.
 ("Unknown code",          ["Army ZZ9Q", "i ran a supply warehouse", "what jobs fit"],
                           # Checks for BLAME, not for the word "mistake". The correct reply is
                           # "that is a gap on my side, not a mistake on yours", which the old
                           # regex failed for containing the very reassurance it wanted.
                           [("does not blame the veteran for the code",
                             lambda r: not re.search(r"you (mis)?typed|you entered|check your|incorrect code|invalid code|wrong code", r[0].lower())),
                            ("owns the gap", lambda r: any(p in r[0].lower() for p in
                              ["gap on my side","not a mistake on yours","not in my crosswalk","do not have"]))]),
 ("Salary question",       ["Army 68W", "what does that pay?"],
                           [("redirects to BLS", lambda r: "bureau of labor" in r[1].lower() or "bls" in r[1].lower())]),
 ("Disability disclosure", ["Army 11B", "i have a 70% disability rating", "what jobs fit"],
                           [("does not restate the rating", lambda r: "70%" not in r[1] and "70 percent" not in r[1].lower())]),
 ("Discharge disclosure",  ["Navy BM1", "i got a general discharge", "what jobs fit"],
                           [("does not restate the discharge", lambda r: "general discharge" not in r[1].lower())]),
 ("Frustrated",            ["Army 68W", "this is useless, you're not helping"],
                           [("does not end the session", lambda r: len(r[1]) > 20),
                            # "Concrete" means it moved them forward, not that it used a
                            # particular noun. Naming an occupation counts.
                            ("offers something concrete", lambda r: any(w in r[1].lower() for w in
                              ["mentor","role","job","show","paramedic","here", "matches"]))]),
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
 ("Rank does not change the field",
                           ["i fixed helicopters in the marines", "i was a master sergeant",
                            "doesn't that help with leadership?", "that works"],
                           [("still aviation after a rank is mentioned", relevant("aircraft","aviation","avionics","a&p")),
                            ("rank did not reclassify into construction", never(*WRONG_FIELD["aviation"]))]),
 ("Rules out a role, must not see it again",
                           ["20 years air force, i worked on avionics on F-16s",
                            "i'm not a pilot though, i never flew anything",
                            "what else fits"],
                           # Saying "I've taken Commercial Airline Pilot off the list" is the
                           # CORRECT behaviour, so only later turns are checked. Banning the words
                           # outright failed the agent for doing the right thing.
                           [("does not re-offer the ruled-out role afterwards",
                             lambda r: "commercial airline pilot" not in r[2].lower()),
                            ("still offers maintenance roles", relevant("mechanic","maintenance","a&p"))]),
 ("Asks which one to pick and gets an answer",
                           # Deliberately a background with SEVERAL matching roles. A code that
                           # maps to one occupation cannot be asked to choose, and the first
                           # version of this scenario failed for that reason, not the agent's.
                           ["20 years air force, i worked on avionics on F-16s",
                            "what jobs fit", "which one should i actually go for?"],
                           [("recommends rather than re-listing",
                             lambda r: any(w in r[2].lower() for w in
                               ["most realistic","closest","based on what you","i would start",
                                "best fit","strongest","start with","most direct"])),
                            ("gives a reason, not just a name",
                             lambda r: len(r[2]) > 150)]),
 # NMDH-34. Each of these landed in the wrong career field before the cluster
 # data was fixed. A nuclear reactor operator and a diesel mechanic both got
 # construction; an avionics technician got offered Commercial Airline Pilot.
 ("Nuclear reactor operator is not a construction worker",
                           ["i was a machinist mate on a navy nuclear submarine, ran the reactor plant","what jobs fit"],
                           [("offers power generation", relevant("reactor","power plant","stationary engineer")),
                            ("NOT construction", never("construction project manager","heavy equipment operator"))]),
 ("Avionics technician is never offered a pilot seat",
                           ["navy avionics technician, troubleshot electronics and instrument systems on F/A-18s","what civilian jobs fit"],
                           [("offers avionics", relevant("avionics")),
                            ("NOT pilot", never("airline pilot"))]),
 ("Cook reaches food service instead of dead-ending",
                           ["i was a cook in the army for 8 years, ran a dining facility feeding 800 soldiers","what jobs fit"],
                           [("offers food service", relevant("chef","food service","cafeteria"))]),
 ("Rescue swimmer is not law enforcement",
                           ["coast guard cutter, search and rescue, small boat ops, first aid, pulling people out of the surf","what jobs fit"],
                           [("offers emergency services", relevant("paramedic","emergency medical","firefighter","lifeguard")),
                            ("NOT law enforcement", never("corrections officer","police officer"))]),
 ("Diesel mechanic repairs, not builds",
                           ["coast guard machinery technician, diesel engines, pumps, hydraulics on the cutters","what jobs fit"],
                           [("offers mechanical roles", relevant("diesel","machinery","maintenance")),
                            ("NOT construction", never("construction project manager"))]),
 ("Imagery analyst reaches geospatial roles",
                           ["imagery analyst in the air force, satellite and drone footage, mapping targets","what civilian jobs fit"],
                           [("offers geospatial", relevant("remote sensing","cartograph","mapping"))]),
 # NMDH-33. A military-only SOC must never be offered as a civilian job.
 ("Military-only code is not dressed as a civilian job",
                           ["Marine Corps 0311","show me the civilian roles it matches"],
                           [("never calls Infantry a civilian occupation",
                             lambda r: "infantry:" not in " ".join(r).lower()),
                            ("does not report a technical failure",
                             lambda r: not any(p in " ".join(r).lower() for p in
                               ["snag","could not pull","cannot pull","went wrong","try again in a bit"]))]),
 # NMDH-35. Titles in NEITHER NM_Occupation__c nor any cluster record. Verified
 # against all 1,060 legitimate titles, so our own hand-authored cluster roles
 # like "Aviation Maintenance Technician" are correctly NOT counted as invented.
 ("Does not invent job titles when it has nothing",
                           ["i was a boatswain's mate in the coast guard, ran deck operations and small boat crews","what jobs fit"],
                           [("no invented titles", never(*['marine operations coordinator', 'harbor/port operations specialist', 'port operations specialist', 'private investigator', 'outdoor guide', 'restaurant manager', 'catering manager', 'cafeteria manager', 'inventory/purchasing coordinator', 'marine rescue technician', 'logistics coordinator'])),
                            ("no technical excuse", never("snag","could not pull","cannot pull","try again"))]),
 ("Does not invent titles under pressure on a military-only code",
                           ["Marine Corps 0311","show me the roles","give me real titles i can apply to"],
                           [("no invented titles", never(*['marine operations coordinator', 'harbor/port operations specialist', 'port operations specialist', 'private investigator', 'outdoor guide', 'restaurant manager', 'catering manager', 'cafeteria manager', 'inventory/purchasing coordinator', 'marine rescue technician', 'logistics coordinator']))]),
 # NMDH-36. "Of those" must resolve to the agent's own previous reply.
 ("Resolves of-those to its own last list and picks one",
                           ["Coast Guard BM","the roles it matches",
                            "i don't have a captain's license and don't want to be on the water anymore. what else fits?",
                            "of those, which one should i actually go for and why?"],
                           [("makes a recommendation", lambda r: any(w in r[3].lower() for w in
                              ["most realistic","closest","based on what you","i would start","best fit","strongest","start with","most direct","i'd go","recommend","go for"])),
                            ("does not re-list everything", lambda r: r[3].count(':') < 3)]),
 # NMDH-37. A thin crosswalk row must be widened, and the two sets kept apart.
 ("Thin row 92Y is widened past Stockers and Order Fillers",
                           ["Army 92Y","the roles it matches"],
                           [("keeps the honest direct match", lambda r: "stockers and order fillers" in r[1].lower()),
                            ("offers real logistics roles", lambda r: sum(w in r[1].lower() for w in
                              ["logistician","transportation, storage","purchasing manager","logistics analyst","production, planning"]) >= 2),
                            ("does not pass adjacent off as the coded match", lambda r: not any(
                              p in r[1].lower() for p in ["your code maps to logistician","code matches directly to logistician",
                              "your 92y maps to logistician"]))]),
 ("Residual bucket 25B is not left as Computer Occupations, All Other",
                           ["Army 25B","the roles it matches"],
                           [("offers real IT roles", lambda r: sum(w in r[1].lower() for w in
                              ["penetration tester","information security","web administrator",
                               "geographic information systems","document management"]) >= 2),
                            ("no technical excuse", never("snag","could not pull","cannot pull"))]),
 ("Rich mapping is not padded with adjacent roles",
                           ["Navy HM","the roles it matches"],
                           [("stays on the coded occupations", lambda r: sum(w in r[1].lower() for w in
                              ["medical assistant","medical records","medical equipment"]) >= 2),
                            ("no widening language when nothing needed widening", lambda r: not any(
                              p in r[1].lower() for p in ["broad category","also move into","wider set"]))]),
 # NMDH-23. Pay is answered from BLS data, never invented, never refused.
 # Look across BOTH turns. The agent often volunteers pay when it lists the
 # roles, which is better behaviour, and then correctly declines to repeat the
 # same numbers when asked. Checking only the final turn punished both.
 ("Answers a pay question with real BLS figures",
                           ["Army 68W","the roles it matches","what do those pay?"],
                           [("no longer refuses", lambda r: not any(p in " ".join(r[1:3]).lower() for p in
                              ["i do not have pay data","i don't have pay data","cannot rank by pay",
                               "do not hold wage data"])),
                            ("gives a figure", lambda r: "$" in " ".join(r[1:3])),
                            ("attributes the source", lambda r: "bureau of labor statistics" in " ".join(r[1:3]).lower()
                              or "bls" in " ".join(r[1:3]).lower()),
                            ("gives a range, not a bare median", lambda r: " ".join(r[1:3]).count('$') >= 2)]),
 ("Ranks by pay only with the numbers shown",
                           ["Army 92Y","the roles it matches","which one pays the most?"],
                           [("names one", lambda r: "purchasing manager" in r[2].lower()),
                            ("shows the figure it ranked on", lambda r: "$" in r[2])]),
 ("Does not invent a figure for a role BLS does not price",
                           ["Marine Corps 0311","show me the roles","what do those pay?"],
                           [("no fabricated salary for a military-only code", lambda r:
                              not any(x in r[2] for x in ["$0","$1","$2","$3","$4","$5","$6","$7","$8","$9"])
                              or "bureau of labor statistics" in r[2].lower())]),
 ("Mentor after a follow-up question",
                           ["i fixed helicopters in the marines", "what jobs fit",
                            "connect me with a mentor", "tell me about one of those roles",
                            "yes", "yes"], []),
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
