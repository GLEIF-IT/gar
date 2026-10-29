#!/usr/bin/env python3
"""
Turn `kli mailbox debug --verbose` output (stdin) into one line per message:
  <topic> <index>  <type> <route>  from <sender>  dt <time>  said <SAID>  [embeds ...]
Headers ("=== Witness", "Local Index per Topic" block) pass through unchanged.
Runs on the host; needs no keystore. Optional argv[1]: a JSON file {AID: alias}
to label senders.
"""
import json
import sys

aliases = {}
if len(sys.argv) > 1:
    try:
        with open(sys.argv[1]) as f:
            aliases = json.load(f)
    except OSError:
        pass

dec = json.JSONDecoder()


def body(text):
    i = text.find("{")
    if i < 0:
        return None
    try:
        obj, _ = dec.raw_decode(text[i:])
        return obj if isinstance(obj, dict) else None
    except ValueError:
        return None


def name(aid):
    return f"{aliases[aid]} ({aid[:12]}..)" if aid in aliases else (aid or "?")


def describe(obj):
    t = obj.get("t", "?")
    r = obj.get("r", "")
    out = [f"{t:<4} {r:<16}", f"from {name(obj.get('i', ''))}", f"dt {str(obj.get('dt', ''))[:19]}",
           f"said {obj.get('d', '?')}"]
    e = obj.get("e")
    if isinstance(e, dict):
        inner = e.get("exn")
        if isinstance(inner, dict):
            ie = inner.get("e") if isinstance(inner.get("e"), dict) else {}
            acdc = ie.get("acdc") if isinstance(ie.get("acdc"), dict) else {}
            out.append(f"embeds exn {inner.get('r')} {inner.get('d')} dt {str(inner.get('dt', ''))[:19]}"
                       + (f" acdc {acdc.get('d')}" if acdc else ""))
        else:
            acdc = e.get("acdc") if isinstance(e.get("acdc"), dict) else None
            anc = e.get("anc") or e.get("ixn") or e.get("rot") or e.get("icp")
            parts = []
            if acdc:
                parts.append(f"acdc {acdc.get('d')}")
            if isinstance(anc, dict):
                parts.append(f"anc {anc.get('t')} sn {int(anc.get('s', '0'), 16)}")
            if parts:
                out.append("embeds " + " ".join(parts))
    elif t == "icp" or t == "rot" or t == "ixn" or t == "rct":
        out[0] = f"{t:<4} sn {int(obj.get('s', '0'), 16):<13}"
        out[1] = f"pre  {name(obj.get('i', ''))}"
    return "  ".join(out)


topic = index = None
for line in sys.stdin:
    line = line.rstrip("\r\n")
    s = line.strip()
    if s.startswith("Topic:"):
        topic = s.split(":", 1)[1].strip()
    elif s.startswith("Index:"):
        index = s.split(":", 1)[1].strip()
    elif s.startswith("{") and topic is not None:
        obj = body(s)
        print(f"{topic:<12} {index:>4}  " + (describe(obj) if obj else s[:60]))
        topic = index = None
    elif s.startswith("Topic ") and ":" in s and not s.startswith("Topic /"):
        print(line)
    elif s == "" or s.startswith("Messages:"):
        continue
    else:
        print(line)
