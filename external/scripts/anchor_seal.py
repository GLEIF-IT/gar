#!/usr/bin/env python3
"""
Prepare the seal for a manual delegation approval.

Use when `kli delegate confirm` does not pick up a QVI's delegated inception or
rotation and the External GARs anchor it by hand with multisig-interact.sh.

Given the three values confirmed with the QARs on the call, the delegate AID
`i`, the hex sequence number `s` and the event SAID `d`, this script:

  1. validates their shape (qb64 AIDs, lowercase hex sequence number);
  2. looks the event up in the local keystore by (i, d), checks that it is a
     delegated inception or rotation at sequence `s` whose delegator is one of
     this keystore's AIDs, and prints the same key-change summary that the
     patched `kli delegate confirm` prints, so it can be read back on the call;
  3. writes the seal to anchor.json for multisig-interact.sh and prints it.

If the event is not in the local keystore the seal is NOT written unless
--force is given; a seal typed from values nobody here can see is the last
resort the coordination process allows, and it says so loudly.

Usage (normally via anchor-seal.sh):
  anchor_seal.py --name <keystore> --passcode <bran> -i <AID> -s <hex sn> -d <SAID> [--out /scripts/anchor.json] [--force]
"""
import argparse
import json
import re
import sys

from keri.app import habbing
from keri.app.cli.common import existing
from keri.core import coring, serdering
from keri.db import dbing


QB64_AID = re.compile(r"^[A-Za-z0-9_-]{44}$")


def validate(i, s, d):
    """Return a list of shape problems with the three seal values (empty if fine)."""
    problems = []
    if not QB64_AID.match(i):
        problems.append(f"-i {i!r} is not a 44 character qb64 AID")
    if not QB64_AID.match(d):
        problems.append(f"-d {d!r} is not a 44 character qb64 SAID")
    if not re.match(r"^[0-9a-f]+$", s):
        problems.append(f"-s {s!r} must be lowercase hex with no prefix (sequence 31 is '1f', not '31' or '0x1f')")
    elif s != "0" and s.startswith("0"):
        problems.append(f"-s {s!r} must not have leading zeros")
    return problems


def check_and_write(hby, i, s, d, out, force=False):
    """Check the event (i, d) in hby, print its summary, write the seal to out.

    Returns 0 on success, 3 if the event is not held locally (or is held but the
    delegate's key state is not) and force is False, 4 if the event is held but
    does not match the given values.
    """
    raw = hby.db.getEvt(dbing.dgKey(i, d))
    found = raw is not None
    ok = True
    unverifiable = False  # event held locally but the delegate's key state is not

    if found:
        serder = serdering.SerderKERI(raw=bytes(raw))
        ked = serder.ked
        ilk = ked["t"]
        print(f"Event {d} found in the local keystore.")
        if ilk == coring.Ilks.dip:
            typ, delpre, dkever = "inception", ked["di"], None
        elif ilk == coring.Ilks.drt:
            typ = "rotation"
            try:
                dkever = hby.kevers[i]  # only item lookup loads a non-own AID's key state in 1.1.44
            except KeyError:
                dkever = None
            if dkever is not None:
                delpre = dkever.delegator
            else:
                # The rotation is here (out-of-order escrow) but the delegate's KEL is not, so
                # neither the delegator nor the key changes can be checked locally.
                delpre = None
                unverifiable = True
                print("  No key state for the delegate in this keystore: its KEL was never loaded, so the")
                print("  delegator and the key changes cannot be checked here. Load it first and re-run:")
                print("    ./scripts/kli.sh oobi resolve --force --oobi <QVI OOBI URL> --oobi-alias <alias>")
        else:
            print(f"  NOT a delegated event: type is '{ilk}', expected 'dip' or 'drt'.")
            typ, delpre, dkever, ok = ilk, "?", None, False

        if ked["s"] != s:
            print(f"  Sequence number MISMATCH: event says s={ked['s']!r}, you gave {s!r}.")
            ok = False
        if serder.pre != i:
            print(f"  Prefix MISMATCH: event is for {serder.pre}, you gave {i}.")
            ok = False
        if delpre is not None and delpre not in hby.prefixes:
            print(f"  Delegator {delpre} is not an AID in this keystore; this GAR cannot approve it.")
            ok = False
        if dkever is not None and dkever.sn >= serder.sn:
            print(f"  Note: local key state for the delegate is already at sn {dkever.sn}; "
                  f"this event may already be accepted.")

        print()
        if unverifiable:
            print("Event as held locally (no prior key state to diff against):")
            print(json.dumps(ked, indent=1))
        else:
            try:
                from keri.app.cli.commands.delegate.confirm import ConfirmDoer
                ConfirmDoer.printSummary(eserder=serder, typ=typ, delpre=delpre, dkever=dkever)
            except (ImportError, AttributeError):
                print("(image lacks the delegate-confirm-summary patch; no key-change summary available)")
                print(json.dumps(ked, indent=1))
    else:
        print(f"Event {d} for {i} is NOT in the local keystore.")
        print("  The delegation request never arrived here, or arrived under a different SAID.")
        if not force:
            print("  Not writing the seal. Re-check the values with the QARs; use --force only if the")
            print("  call has confirmed all three and you accept anchoring an event this keystore cannot see.")
            return 3
        print("  --force given: writing the seal from the call-confirmed values.")
        print()

    if found and not ok:
        print("\nNot writing the seal; resolve the mismatches above first.")
        return 4

    if found and unverifiable and not force:
        print("\nNot writing the seal: the event is held here but cannot be verified without the delegate's")
        print("key state. Load its KEL as shown above, or use --force only if the call has confirmed all three values.")
        return 3

    seal = dict(i=i, s=s, d=d)
    with open(out, "w") as f:
        json.dump(seal, f, indent=2)
        f.write("\n")
    print(f"Seal written to {out}:")
    print(json.dumps(seal, indent=2))
    print("\nRead i, s and d back on the call once more, then run multisig-interact.sh.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", "-n", required=True)
    parser.add_argument("--base", "-b", default="")
    parser.add_argument("--passcode", "-p", dest="bran", default=None)
    parser.add_argument("-i", required=True, help="delegate AID (the QVI AID being approved)")
    parser.add_argument("-s", required=True, help="sequence number of the delegated event, hex as it appears in the event")
    parser.add_argument("-d", required=True, help="SAID of the delegated event")
    parser.add_argument("--out", default="/scripts/anchor.json", help="where to write the seal")
    parser.add_argument("--force", action="store_true", help="write the seal even if the event is not in the local keystore")
    parser.add_argument("--temp", action="store_true", help=argparse.SUPPRESS)  # self-test only
    args = parser.parse_args()


    problems = validate(args.i, args.s, args.d)
    if problems:
        print("Refusing to build a seal:")
        for p in problems:
            print(f"  {p}")
        sys.exit(2)

    if args.temp:
        hby = habbing.Habery(name=args.name, base=args.base, bran=args.bran, temp=True)
    else:
        hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        sys.exit(check_and_write(hby, args.i, args.s, args.d, args.out, force=args.force))
    finally:
        hby.close()


if __name__ == "__main__":
    main()
