#!/usr/bin/env python3
"""
Ingest a CESR stream produced by `kli vc export --full` on another keystore of
the same group: the issuer KEL(s), registry and credential TEL(s), any chained
credentials and the credential itself. Use it when this keystore is missing a
credential that another member holds (e.g. the Legal Entity credential an
OOR/ECR authorization chains to) and the mailbox route no longer delivers it.

Reads the stream through the same Kevery / Tevery / Verifier path the mailbox
poller uses, runs the escrows until nothing moves, then reports whether each
credential in the stream is now saved and indexed here.

Usage (normally via import-credential.sh):
  import_credential.py --name <keystore> --passcode <bran> --file <stream.cesr>
"""
import argparse
import sys

from keri.app.cli.common import existing
from keri.core import eventing, parsing, serdering
from keri.vdr import credentialing, verifying
from keri.vdr.eventing import Tevery

from sent_exns import credential_state


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--file", "-f", required=True, help="CESR stream from `kli vc export --full`")
    return p.parse_args()


def credential_saids(raw):
    """SAIDs of the ACDCs in the stream (by scanning for ACDC version strings), in order."""
    saids = []
    pos = 0
    while True:
        i = raw.find(b'{"v":"ACDC', pos)
        if i < 0:
            break
        try:
            creder = serdering.SerderACDC(raw=raw[i:])
            saids.append(creder.said)
            pos = i + creder.size
        except Exception:
            pos = i + 1
    return saids


def main():
    args = parse_args()
    with open(args.file, "rb") as f:
        raw = f.read().replace(b"\r", b"")
    if not raw.strip():
        print("empty stream", file=sys.stderr)
        return 2
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
        reger = rgy.reger
        # Same settings as the mailbox poller: these are remote events, not our own.
        kvy = eventing.Kevery(db=hby.db, lax=True, local=False, direct=False)
        vry = verifying.Verifier(hby=hby, reger=reger)
        tvy = Tevery(reger=reger, db=hby.db, lax=True, local=False)
        psr = parsing.Parser(kvy=kvy, tvy=tvy, vry=vry)
        wanted = credential_saids(raw)
        print(f"stream: {len(raw)} bytes, {len(wanted)} credential(s): {', '.join(wanted) or '-'}")
        before = {s: reger.saved.get(keys=s) is not None for s in wanted}
        psr.parse(ims=bytearray(raw))
        # Escrows: KEL first (TEL anchors need it), then TEL, then credentials (chains need earlier creds).
        for _ in range(10):
            kvy.processEscrows()
            tvy.processEscrows()
            vry.processEscrows()
            if all(reger.saved.get(keys=s) is not None for s in wanted):
                break
        rc = 0
        for s in wanted:
            saved = reger.saved.get(keys=s) is not None
            print(f"  {s}  saved {saved}{' (already)' if before[s] else ''}  TEL state {credential_state(reger, s)}")
            if not saved:
                rc = 1
                held = []
                for label, table in (("missing registry/TEL", reger.mre), ("missing chain", reger.mce), ("missing schema", reger.mse)):
                    if table.get(keys=(s,)) is not None:
                        held.append(label)
                print(f"      not saved; verifier escrow: {', '.join(held) or 'none (rejected, see stderr)'}")
        return rc
    finally:
        hby.close()


if __name__ == "__main__":
    sys.exit(main())
