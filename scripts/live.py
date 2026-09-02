"""Adaptive driver. Keeps ONE session open across calls so the next message can
be chosen after reading the last reply, the way a person actually talks."""
import json, urllib.request, sys, os, textwrap
BASE="https://orgfarm-3bfff135af.my.site.com/nextmission/webruntime/api/apex/execute"
STATE="/tmp/nm_live_session.txt"
def call(method, params):
    p={"namespace":"","classname":"NM_AgentController","method":method,
       "params":params,"cacheable":False,"isContinuation":False}
    r=urllib.request.Request(BASE,data=json.dumps(p).encode(),headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(r,timeout=200).read())
if sys.argv[1]=="new":
    sid=call("startSession",{"sourceUrl":"https://live-sim"})["returnValue"]["sessionId"]
    open(STATE,"w").write(sid); print("new session")
else:
    sid=open(STATE).read().strip()
    for msg in sys.argv[1:]:
        rv=call("sendMessage",{"sessionId":sid,"text":msg,"sourceUrl":"https://live-sim"})["returnValue"]
        print("YOU  > %s" % msg)
        print("AGENT> %s\n" % textwrap.fill((rv.get("replyText") or "").strip(),110,subsequent_indent="       "))
