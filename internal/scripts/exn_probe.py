#!/usr/bin/env python3
"""
Feed one raw mailbox message through the same parser and exchange handlers
that `kli challenge verify` uses, against the real keystore, with keripy
logging on, and report what happened to it: accepted, escrowed, or dropped.

The message text is exactly what mailbox-debug.sh --verbose prints for one
message (the JSON body immediately followed by its CESR attachments).

If the message is accepted it is stored just as if the mailbox poller had
received it, so a following `kli challenge verify` finds it immediately.

Usage (normally via exn-probe.sh):
  exn_probe.py --name <keystore> --passcode <bran> --file <message file>
  exn_probe.py --temp --kel <cesr stream> --file <message file>   # self-test
"""
import argparse
import logging
import re
import sys

parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument("--name", "-n", default="probe")
parser.add_argument("--base", "-b", default="")
parser.add_argument("--passcode", "-p", dest="bran", default=None)
parser.add_argument("--file", "-f", required=True, help="file holding the raw message")
parser.add_argument("--temp", action="store_true", help="use a throwaway keystore (self-test)")
parser.add_argument("--kel", help="with --temp: CESR stream (e.g. an OOBI response) to preload")
parser.add_argument("--quiet", "-q", action="store_true", help="suppress keripy debug logging")
args = parser.parse_args()

if not args.quiet:
    logging.basicConfig(level=logging.DEBUG, stream=sys.stdout, format="  log %(levelname)s %(name)s: %(message)s")
    for name in ("keri", "hio"):
        logging.getLogger(name).setLevel(logging.DEBUG)

from keri import help, kering
from keri.app import challenging, signaling
from keri.app.cli.common import existing
from keri.core import parsing, eventing, routing
from keri.peer import exchanging

help.ogler.level = logging.DEBUG
lg = help.ogler.getLogger()
lg.setLevel(logging.DEBUG)
if not args.quiet and not any(isinstance(h, logging.StreamHandler) for h in lg.handlers):
    lg.addHandler(logging.StreamHandler(sys.stdout))
if args.quiet:
    logging.disable(logging.CRITICAL)

msg = open(args.file, "rb").read().strip()
m = re.search(rb'"i":"([^"]+)"', msg)
d = re.search(rb'"d":"([^"]+)"', msg)
sender = m.group(1).decode() if m else None
said = d.group(1).decode() if d else None
print(f"message: {len(msg)} bytes, sender={sender}, said={said}, has rp={b'\"rp\"' in msg}")

if args.temp:
    from keri.app import habbing
    hby = habbing.Habery(name=args.name, base=args.base, bran=args.bran, temp=True)
else:
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
try:
    rvy = routing.Revery(db=hby.db)
    kvy = eventing.Kevery(db=hby.db, lax=True, local=False, rvy=rvy)
    if args.kel:
        parsing.Parser(framed=True, kvy=kvy, rvy=rvy).parse(ims=bytearray(open(args.kel, "rb").read()))
        kvy.processEscrows()
        rvy.processEscrowReply()

    exc = exchanging.Exchanger(hby=hby, handlers=[])
    challenging.loadHandlers(db=hby.db, signaler=signaling.Signaler(), exc=exc)

    kever = hby.kevers.get(sender) if sender else None
    print(f"sender key state present: {kever is not None}" + (f" (sn {kever.sn})" if kever else ""))

    reps_before = {s.qb64 for s in hby.db.reps.get(keys=(sender,))} if sender else set()
    escrow_before = {k for k, _ in hby.db.epse.getItemIter()}

    print("---- parsing")
    ims = bytearray(msg)
    parsing.Parser(framed=True, kvy=kvy, rvy=rvy, exc=exc).parse(ims=ims)
    exc.processEscrow()
    print("---- result")

    reps_after = {s.qb64 for s in hby.db.reps.get(keys=(sender,))} if sender else set()
    escrow_after = {k for k, _ in hby.db.epse.getItemIter()}
    stored = hby.db.exns.get(keys=(said,)) is not None if said else False
    cues = [c.get("kin") for c in exc.cues]

    print(f"unparsed bytes left : {len(ims)}")
    print(f"exn stored          : {stored}")
    print(f"response recorded   : {said in reps_after}  (responses from sender before={len(reps_before)} after={len(reps_after)})")
    print(f"escrowed now        : {said in escrow_after}  (escrow entries before={len(escrow_before)} after={len(escrow_after)})")
    print(f"exchanger cues      : {cues}")
    if said in reps_after:
        print("VERDICT: accepted. `kli challenge verify` with the same words should now succeed immediately.")
    elif said in escrow_after:
        print("VERDICT: escrowed. Signature could not be verified against the sender's key state.")
    else:
        print("VERDICT: dropped. See the log lines above for the parser's reason.")
finally:
    hby.close()
