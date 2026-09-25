#!/usr/bin/env python3
"""
Read-only preflight for approving a QVI's delegated rotation with `kli delegate confirm`.

`delegate confirm` only shows a rotation whose prior KEL this keystore already
holds. If the QVI's key state is missing, its rotation lands in the out-of-order
escrow instead, confirm sits waiting forever, and anchor-seal.sh cannot verify
the event either. Every External GAR on the call needs the QVI's KEL, so run
this before the call and fix anything it reports.

It prints, without changing anything:

  1. the External group AID, its members and which one is yours;
  2. the QVI's current key state as held here (sn, SAID, thresholds, keys,
     next-key digests, witnesses), so the rotation you approve must be sn + 1;
  3. any delegated events for the QVI sitting in escrow right now. Loading the
     KEL with `kli oobi resolve --force` also drops the QVI's latest, already
     accepted rotation into the partially-signed escrow, and `delegate confirm`
     would offer that one first. Such an entry (s not above the current sn) is
     reported as stale; --clear-stale removes exactly those entries;
  4. whether the External AID's witness (where the request arrives) answers;
  5. the seal currently in scripts/anchor.json, since multisig-interact.sh
     anchors whatever is there.

Usage (normally via delegate-confirm-preflight.sh):
  delegate_confirm_preflight.py --name <keystore> --passcode <bran> [--alias "GLEIF External AID"]
                                [--delegate <QVI AID or contact alias>] [--anchor /scripts/anchor.json]
                                [--clear-stale]
"""
import argparse
import json
import os
import sys
import urllib.request

from keri.app import connecting
from keri.app.cli.common import existing
from keri.core import serdering
from keri.db import dbing


def kever_for(hby, pre):
    """Key state for pre or None. In keripy 1.1.44 hby.kevers only preloads this
    keystore's own AIDs; any other AID is loaded on item lookup, so `in` and
    .get() say nothing about it."""
    try:
        return hby.kevers[pre]
    except KeyError:
        return None


def pending(db, pre):
    """Delegated events for pre in the escrows delegate confirm reads (pses) and
    the one it does not (ooes). Returns a list of (escrow name, SerderKERI, remove)
    where remove() deletes that escrow entry (the event itself stays in the db)."""
    out = []
    for name, it, dele in (("partially-signed (confirm sees these)", db.getPseItemsNextIter(), db.delPse),
                           ("out-of-order (confirm does NOT see these)", db.getOoeItemIter(), db.delOoe)):
        for ekey, edig in it:
            epre, _ = dbing.splitKeySN(bytes(ekey))
            if epre.decode() != pre:
                continue
            raw = db.getEvt(dbing.dgKey(epre, bytes(edig)))
            if raw is not None:
                out.append((name, serdering.SerderKERI(raw=bytes(raw)),
                            lambda ekey=bytes(ekey), edig=bytes(edig), dele=dele: dele(ekey, edig)))
    return out


def reachable(url):
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            return resp.status
    except Exception as ex:  # any failure is a failure for this purpose
        return str(ex)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", "-n", required=True)
    parser.add_argument("--base", "-b", default="")
    parser.add_argument("--passcode", "-p", dest="bran", default=None)
    parser.add_argument("--alias", default="GLEIF External AID", help="alias of the External group AID")
    parser.add_argument("--delegate", default=None, help="QVI AID or contact alias; default: every delegate of the External AID")
    parser.add_argument("--anchor", default="/scripts/anchor.json", help="anchor.json that multisig-interact.sh would use")
    parser.add_argument("--clear-stale", action="store_true",
                        help="remove escrow entries for events the QVI's key state already includes")
    args = parser.parse_args()

    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        return run(hby, args)
    finally:
        hby.close()


def run(hby, args):
    passed = True
    org = connecting.Organizer(hby=hby)

    ghab = hby.habByName(args.alias)
    if ghab is None:
        print(f"FAIL: alias {args.alias!r} not found in keystore {args.name!r}")
        return 2
    print(f"External AID   {ghab.pre}  (alias {args.alias!r}, sn {ghab.kever.sn})")
    for mid in ghab.smids:
        tag = "you" if ghab.mhab is not None and mid == ghab.mhab.pre else (org.get(mid) or {}).get("alias", "?")
        print(f"  member       {mid}  {tag}")
    print(f"  kt {ghab.kever.tholder.sith!r}  witnesses {ghab.kever.wits}")

    # Which delegate(s) to check.
    if args.delegate:
        pre = args.delegate
        for c in org.list():
            if c.get("alias") == args.delegate:
                pre = c["id"]
                break
        delegates = [pre]
    else:
        delegates = [keys[0] for keys, ksr in hby.db.states.getItemIter() if ksr.di == ghab.pre]
        if not delegates:
            print("\nFAIL: this keystore holds no key state for any AID delegated by the External AID.")
            print("      Load the QVI's KEL, then run this again (the plain resolve skips a URL resolved before):")
            print("        ./scripts/kli.sh oobi resolve --force --oobi <QVI OOBI URL> --oobi-alias <alias>")
            print("      Contacts here that look like QVIs:")
            for c in org.list():
                if c.get("id", "").startswith("E"):
                    print(f"        {c.get('alias')}  {c['id']}  {c.get('oobi', '')}")
            passed = False

    for pre in delegates:
        contact = org.get(pre) or {}
        print(f"\nDelegate       {pre}  (contact alias {contact.get('alias', '?')!r})")
        kever = kever_for(hby, pre)
        if kever is None:
            print("  FAIL: no key state held here. Load its KEL and run this again:")
            oobi = contact.get("oobi", "<QVI OOBI URL>")
            print(f"        ./scripts/kli.sh oobi resolve --force --oobi {oobi} --oobi-alias {contact.get('alias', '<alias>')}")
            passed = False
        else:
            if kever.delegator != ghab.pre:
                print(f"  FAIL: delegator is {kever.delegator}, not the External AID")
                passed = False
            print(f"  sn {kever.sn} (hex {kever.serder.ked['s']})  last {kever.serder.ked['t']}  SAID {kever.serder.said}")
            print(f"  the rotation to approve must be  s = {kever.sn + 1:x}")
            print(f"  kt {kever.tholder.sith!r}  signing keys:")
            for v in kever.verfers:
                print(f"      {v.qb64}")
            print(f"  nt {kever.ntholder.sith!r}  next key digests:")
            for d in kever.ndigers:
                print(f"      {d.qb64}")
            print(f"  toad {kever.toader.num}  witnesses:")
            for w in kever.wits:
                print(f"      {w}")

        esc = pending(hby.db, pre)
        if esc:
            print("  delegated events for this AID in escrow now:")
            for name, s, remove in esc:
                stale = kever is not None and s.sn <= kever.sn
                line = f"      {s.ked['t']} s={s.ked['s']} d={s.said}  [{name}]"
                if not stale:
                    print(line)
                elif args.clear_stale:
                    remove()
                    print(line + "  STALE (already accepted), removed from escrow")
                else:
                    print(line + "  STALE: already accepted, but delegate confirm would still offer it first")
                    print("        answer n if it appears, or run this again with --clear-stale to remove it")
        else:
            print("  nothing for this AID in escrow now")

    print("\nExternal AID witnesses (the delegation request arrives via their mailbox):")
    for w in ghab.kever.wits:
        urls = [loc.url for keys, loc in hby.db.locs.getItemIter(keys=(w,))]
        if not urls:
            print(f"  FAIL: no known URL for witness {w}")
            passed = False
        for url in urls:
            status = reachable(f"{url.rstrip('/')}/oobi/{w}/controller")
            ok = status == 200
            passed &= ok
            print(f"  [{'OK  ' if ok else 'FAIL'}] {w} {url} -> {status}")

    print(f"\nSeal in {args.anchor} (multisig-interact.sh anchors this file as-is):")
    if os.path.exists(args.anchor):
        with open(args.anchor) as f:
            print("  " + f.read().strip().replace("\n", "\n  "))
        print("  WARNING: only run multisig-interact.sh after anchor-seal.sh has rewritten this for the current rotation.")
    else:
        print("  (none)")

    print(f"\nresult: {'PASS' if passed else 'FAIL'}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
