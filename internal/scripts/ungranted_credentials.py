#!/usr/bin/env python3
"""
List the credentials the group AID has created (issued into its registry) but
never granted: no /ipex/grant exn embedding the credential was fully signed by
this keystore. These are the credentials still waiting for grant-*-credential.sh.

Reads the same local tables as contacts-credentials.sh: the credentials indexed
as issued by the group AID, their registry (TEL) state, and the keystore's own
record of every /ipex/grant exn it completed. --poll checks your mailboxes first.

Usage (normally via ungranted-credentials.sh):
  ungranted_credentials.py --name <keystore> --passcode <bran> --alias <group alias>
                           [--poll SECONDS] [--json]

--json prints one JSON array of credential records (as contacts-credentials.sh --json).
"""
import argparse
import json
import sys

from keri.app import connecting
from keri.app.cli.common import existing
from keri.vdr import credentialing

# Same directory (mounted at /scripts in the container).
from contacts_credentials import grants_by_credential, issued_credentials
from sent_exns import poll


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--alias", "-a", required=True, help="alias of the issuing (group) AID")
    p.add_argument("--poll", type=float, default=0, metavar="SECONDS",
                   help="poll your mailboxes for this long first (topics /credential /replay /reply)")
    p.add_argument("--json", "-j", action="store_true", help="emit one JSON array instead of text (for jq)")
    return p.parse_args()


def main():
    args = parse_args()
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        hab = hby.habByName(args.alias)
        if hab is None:
            print(f"alias {args.alias!r} not found in keystore {hby.name!r}", file=sys.stderr)
            return 2
        if args.poll:
            poll(hby, args.poll)
        org = connecting.Organizer(hby=hby)
        rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
        grants = grants_by_credential(hby, org, hab.pre)
        creds = issued_credentials(hby, org, rgy, hab.pre, grants)
        ungranted = [c for c in creds if not c["grants"]]
        if args.json:
            print(json.dumps(ungranted, indent=2))
            return 0
        render(hab, creds, ungranted)
        return 0
    finally:
        hby.close()


def render(hab, creds, ungranted):
    def name(p):
        return f"{p['alias']} ({p['pre']})" if p and p.get("alias") else (p or {}).get("pre") or "?"

    print()
    print(f"Issuer: {hab.name} ({hab.pre})")
    print(f"{len(ungranted)} of {len(creds)} issued credential(s) have no grant sent")
    for cred in ungranted:
        print()
        print(f"  {cred['said']}  {cred['type']}  [{cred['status']}]")
        parts = []
        if cred["issuee"]:
            parts.append(f"issuee {name(cred['issuee'])}")
        if cred["person"]:
            parts.append(f"person {name(cred['person'])}")
        if parts:
            print("      " + "  |  ".join(parts))
        detail = [cred["personLegalName"], cred["role"], f"LEI {cred['LEI']}" if cred["LEI"] else None,
                  f"issued {cred['dt'][:19]}" if cred["dt"] else None]
        detail = [d for d in detail if d]
        if detail:
            print("      " + "  |  ".join(detail))


if __name__ == "__main__":
    sys.exit(main())
