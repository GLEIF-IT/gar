#!/usr/bin/env python3
"""
Repair missing delegation seal records on a keripy witness.

Run on the witness host, against the witness keystore, with the witness
process stopped:

  python3 repair_delegation_seals.py --name <witness keystore name> [--base <base>] [--dry-run]

"""
import argparse
import sys

from keri.app import habbing
from keri.core import coring, serdering
from keri.db import dbing

DELEGATE = "EGExS84NI2jK8_wpM5RHX3ybhJwQ8WUBqWR0W5O-n-sM"   # Global vLEI QVI AID
DELEGATOR = "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS"  # GLEIF External AID

# (delegate event SAID, delegator event sn, delegator event SAID)
SEALS = [
    ("EGExS84NI2jK8_wpM5RHX3ybhJwQ8WUBqWR0W5O-n-sM", 15, "EFl2etHgA5W92IaXIBauBhn-BaEvXFGJhmep2Zm5j8Ka"),  # dip s=0
    ("ED2YBHC0TRImf5GlJ30WQ0BJXECKY2ikxYX8oNo8ugW1",  26, "ENPJ6CyEy8ECNKE6qL98YFFQQ2E2vbg7tiMrO4ILT2vQ"),  # drt s=9
    ("EHj3wcptXkAVCbTPWUc-osOGDjCRhGSe2Ib1MD7gtoLJ",  27, "EK7xCH5pg1hqQpZs02CZXvNEcby7QDhhCC2lAx8TS0YH"),  # drt s=20
]


def repair(db, dry_run=False):
    ok = True
    for dsaid, sn, asaid in SEALS:
        dkey = dbing.dgKey(DELEGATE, dsaid)
        draw = db.getEvt(dkey)
        if draw is None:
            print(f"MISSING delegate event {dsaid}: not held by this witness, skipping")
            ok = False
            continue
        dserder = serdering.SerderKERI(raw=bytes(draw))

        araw = db.getEvt(dbing.dgKey(DELEGATOR, asaid))
        if araw is None:
            print(f"MISSING delegator event sn {sn} {asaid}: not held by this witness, skipping")
            ok = False
            continue
        aserder = serdering.SerderKERI(raw=bytes(araw))
        if aserder.sn != sn:
            print(f"MISMATCH delegator event {asaid} is sn {aserder.sn}, expected {sn}, skipping")
            ok = False
            continue
        seals = [a for a in (aserder.ked.get("a") or []) if isinstance(a, dict)
                 and a.get("i") == DELEGATE and a.get("d") == dsaid and int(a.get("s", "0"), 16) == dserder.sn]
        if not seals:
            print(f"MISMATCH delegator event sn {sn} does not seal {dsaid}, skipping")
            ok = False
            continue

        couple = coring.Seqner(sn=sn).qb64b + coring.Saider(qb64=asaid).qb64b
        existing = db.getAes(dkey)
        if existing is not None and bytes(existing) == couple:
            print(f"ok      {dserder.ked['t']} s={dserder.sn:<2} {dsaid[:16]}  seal record already present")
            continue
        state = "REPLACE" if existing is not None else "write  "
        if dry_run:
            print(f"{state} {dserder.ked['t']} s={dserder.sn:<2} {dsaid[:16]}  <- delegator sn {sn} {asaid[:16]}  (dry run)")
        else:
            db.setAes(dkey, couple)
            print(f"{state} {dserder.ked['t']} s={dserder.sn:<2} {dsaid[:16]}  <- delegator sn {sn} {asaid[:16]}")
    return ok


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True, help="witness keystore name (as given to kli witness start)")
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    hby = habbing.Habery(name=args.name, base=args.base, bran=args.bran, temp=False)
    try:
        ok = repair(hby.db, dry_run=args.dry_run)
        print("done" if ok else "done with skips; see above")
        return 0 if ok else 1
    finally:
        hby.close()


if __name__ == "__main__":
    sys.exit(main())
