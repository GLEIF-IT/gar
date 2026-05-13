#!/usr/bin/env python3
import argparse
import sys

from keri.app.cli.common import existing
from keri.db import dbing
from keri.core import serdering


def parse_args():
    p = argparse.ArgumentParser(
        description="Read-only preflight for `kli multisig rotate`",
    )
    p.add_argument("--name", required=True,
                   help="keystore name (passed by the wrapper)")
    p.add_argument("--base", default="",
                   help="keystore base prefix (defaults to empty, matching kli)")
    p.add_argument("--passcode", required=True,
                   help="keystore passcode (passed by the wrapper)")
    p.add_argument("--alias", required=True,
                   help="human-readable alias of the group hab")
    p.add_argument("--smids", action="append", required=True,
                   help="signing member AID; repeat per member; PREFIX or PREFIX:N")
    p.add_argument("--rmids", action="append", default=None,
                   help="rotation member AID; repeat per member; "
                        "defaults to smids when omitted")
    return p.parse_args()


def check_one(hby, raw):
    """Returns (ok: bool, detail: str) for one smid/rmid value."""
    parts = raw.split(":")
    mid = parts[0]
    in_kevers = mid in hby.kevers
    in_states = hby.db.states.get(keys=mid) is not None

    if not in_kevers:
        return False, f"kevers={in_kevers} states={in_states}"

    if len(parts) == 1:
        return True, f"kevers={in_kevers} states={in_states}"

    # parts == [mid, sn] — mirror rotate.py:151-165
    try:
        sn = int(parts[1])
    except ValueError:
        return False, f"invalid sn={parts[1]!r}"

    dig = hby.db.getKeLast(dbing.snKey(mid, sn))
    if dig is None:
        return False, (f"kevers={in_kevers} states={in_states} "
                       f"no event at sn={sn}")

    evt = hby.db.getEvt(dbing.dgKey(mid, bytes(dig)))
    ser = serdering.SerderKERI(raw=bytes(evt))
    if not ser.estive:
        return False, f"event at sn={sn} not an establishment event"

    return True, (f"kevers={in_kevers} states={in_states} "
                  f"sn={sn} estive=True")


def check_list(hby, label, items):
    print(f"\n{label}:")
    all_ok = True
    for raw in items:
        ok, detail = check_one(hby, raw)
        marker = "OK  " if ok else "MISS"
        print(f"  [{marker}] {raw}  {detail}")
        all_ok &= ok
    return all_ok


def main():
    args = parse_args()

    hby = existing.setupHby(name=args.name, base=args.base, bran=args.passcode)
    ghab = hby.habByName(args.alias)
    if ghab is None:
        print(
            f"ERROR: alias {args.alias!r} not found in keystore "
            f"{args.name!r} (base={args.base!r})",
            file=sys.stderr,
        )
        return 2

    print(f"keystore name:   {args.name}")
    print(f"keystore base:   {args.base!r}")
    print(f"group prefix:    {ghab.pre}")
    print(f"local mhab.pre:  {ghab.mhab.pre}")

    ok_smids = check_list(hby, "smids", args.smids)
    ok_rmids = check_list(hby, "rmids", args.rmids or args.smids)

    smid_prefixes = [s.split(":")[0] for s in args.smids]
    mhab_in_smids = ghab.mhab.pre in smid_prefixes
    print(f"\nlocal mhab in smids: {mhab_in_smids}")

    passed = ok_smids and ok_rmids and mhab_in_smids
    print(f"\nresult: {'PASS' if passed else 'FAIL'}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
