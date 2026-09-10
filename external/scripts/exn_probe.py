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
  exn_probe.py --name <keystore> --passcode <bran> --file <message file> --poll 60
  exn_probe.py --temp --kel <cesr stream> --file <message file>   # self-test

With --poll N the message is NOT parsed directly. Instead the real mailbox
director is run for N seconds, exactly as `kli challenge verify` runs it,
polling every witness of every AID in the keystore on the /challenge topic.
The report then says whether the message in --file arrived through that path.
Rewind the local index for the right AID and witness first (mailbox-update.sh
with -a <alias>) or the poller will not ask for it again.
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
parser.add_argument("--poll", type=float, default=0, metavar="SECONDS",
                    help="run the real mailbox poller for this long instead of parsing --file directly")
parser.add_argument("--verbose", "-V", action="store_true", help="with --poll: stream full keripy debug logging (very noisy)")
args = parser.parse_args()

# keripy 1.1.x has a broken debug format string that raises inside logging on every
# escrow retry; without this, every retry dumps a traceback to stderr.
logging.raiseExceptions = False

# Poll mode is quiet by default: the director logs at debug level on every tock.
# Informative keri lines (INFO and up) are collected and summarised at the end.
stream_logs = (not args.quiet) and (not args.poll or args.verbose)
collected = []
class Collect(logging.Handler):
    def emit(self, record):
        try:
            text = record.getMessage()
        except Exception:
            return
        if len(collected) < 200:
            collected.append(f"{record.levelname} {text.splitlines()[0][:160]}")

if stream_logs:
    logging.basicConfig(level=logging.DEBUG, stream=sys.stdout, format="  log %(levelname)s %(name)s: %(message)s")
    for name in ("keri", "hio"):
        logging.getLogger(name).setLevel(logging.DEBUG)

from keri import help, kering
from keri.app import challenging, signaling
from keri.app.cli.common import existing
from keri.core import parsing, eventing, routing
from keri.peer import exchanging

lg = help.ogler.getLogger()
if stream_logs:
    help.ogler.level = logging.DEBUG   # also opens hio's console handler at debug
    lg.setLevel(logging.DEBUG)
    if not any(isinstance(h, logging.StreamHandler) for h in lg.handlers):
        lg.addHandler(logging.StreamHandler(sys.stdout))
elif args.quiet:
    logging.disable(logging.CRITICAL)
else:
    # Leave hio's console handler at its default (silent) level; raise only the
    # logger so the collector below sees INFO and above.
    for lg_ in (lg, logging.getLogger("keri")):
        lg_.setLevel(logging.INFO)
        for h in lg_.handlers:          # hio's console handlers: errors only
            h.setLevel(logging.ERROR)
        h = Collect(); h.setLevel(logging.INFO); lg_.addHandler(h)

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

    # hby.kevers loads lazily from the db on __getitem__/__contains__; its get() does not
    kever = hby.kevers[sender] if sender and sender in hby.kevers else None
    print(f"sender key state present: {kever is not None}" + (f" (sn {kever.sn})" if kever else ""))

    reps_before = {s.qb64 for s in hby.db.reps.get(keys=(sender,))} if sender else set()
    escrow_before = {k for k, _ in hby.db.epse.getItemIter()}

    # Collect the exchanger's "Saved exn event" log lines for our SAID; that line is
    # emitted every time the message is processed, even if it was stored before.
    saved = []
    class Catch(logging.Handler):
        def emit(self, record):
            try:
                text = record.getMessage()
            except Exception:
                return
            if said and "Saved exn event" in text and said in text:
                saved.append(text)
    for lg_ in (lg, logging.getLogger("keri")):
        lg_.addHandler(Catch())

    def index_snapshot():
        snap = {}
        for (pre, wit), rec in hby.db.tops.getItemIter():
            if "/challenge" in rec.topics:
                snap[(pre, wit)] = rec.topics["/challenge"]
        return snap

    ims = bytearray(msg)
    if args.poll:
        from hio.base import doing
        from keri.app import indirecting
        before_idx = index_snapshot()
        print(f"---- polling for {args.poll:.0f}s via MailboxDirector (topics ['/challenge'])")
        mbd = indirecting.MailboxDirector(hby=hby, topics=["/challenge"], exc=exc)
        doist = doing.Doist(limit=args.poll, tock=0.03125, real=True)
        collected.clear()   # only keep what is logged during the poll itself
        # No HaberyDoer here: it would close the keystore when the doist finishes,
        # and the report below still needs to read it.
        doist.do(doers=[mbd])
        after_idx = index_snapshot()
        print("---- result")
        for key in sorted(set(before_idx) | set(after_idx)):
            b, a = before_idx.get(key), after_idx.get(key)
            if b != a:
                print(f"index moved     : {key[0][:12]}.. @ {key[1][:12]}..  /challenge {b} -> {a}")
        print(f"pollers created     : {len(mbd.pollers)}")
        if collected:
            print("---- keri log lines (INFO and above) during the poll")
            seen = set()
            for line in collected:
                if line not in seen:
                    seen.add(line); print("  " + line)
        print(f"processed via poller: {len(saved) > 0}  (\"Saved exn event\" log lines for this SAID: {len(saved)})")
    else:
        print("---- parsing")
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
    if args.poll and not saved:
        print("VERDICT: the poller did not deliver this message. If no index moved, the local index was not\n"
              "         rewound for the right AID/witness or the poller never reached that witness; see the log.")
    elif args.poll:
        print("VERDICT: delivered and processed through the poller path.")
    elif said in reps_after:
        print("VERDICT: accepted. `kli challenge verify` with the same words should now succeed immediately.")
    elif said in escrow_after:
        print("VERDICT: escrowed. Signature could not be verified against the sender's key state.")
    else:
        print("VERDICT: dropped. See the log lines above for the parser's reason.")
finally:
    hby.close()
