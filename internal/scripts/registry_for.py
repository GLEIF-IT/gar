#!/usr/bin/env python3
"""
Print the local registry name to revoke a credential in, after checking it can
be revoked from this keystore.

`kli vc revoke --registry-name NAME` builds the rev event in the registry NAME
refers to, not in the one the credential names in its `ri` field, so passing
INT_GAR_REG_NAME / EXT_GAR_REG_NAME blindly breaks for any credential issued
into another registry of the group. This finds the credential, takes its `ri`,
and prints the local name registered for that registry. If that registry is
not registered here but its TEL is, and the group incepted it, it is
registered first (one local record, as adopt-registry.sh writes).

Exits non-zero with the reason on stderr when the credential is not held
here, has no TEL issuance here, is already revoked, or was not issued by the
group. The name is the only thing printed on stdout.

Usage (from the revoke-*.sh scripts):
  registry_for.py --name <keystore> --passcode <bran> --alias <group alias>
                  --registry-name <preferred name> --said <credential SAID>
"""
import argparse
import contextlib
import sys

from keri.app.cli.common import existing
from keri.app.habbing import GroupHab
from keri.vdr import credentialing

from adopt_registry import ensure_registered
from revoke_readiness import tel_state


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--alias", "-a", required=True, help="alias of the group AID")
    p.add_argument("--registry-name", "-r", required=True, help="INT_GAR_REG_NAME / EXT_GAR_REG_NAME")
    p.add_argument("--said", "-s", required=True, help="credential to revoke")
    return p.parse_args()


def fail(msg):
    print(msg, file=sys.stderr)
    return 1


def main():
    args = parse_args()
    said = args.said.strip()
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        ghab = hby.habByName(args.alias)
        if ghab is None or not isinstance(ghab, GroupHab):
            return fail(f"group alias {args.alias!r} not found in keystore {hby.name!r}")
        rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
        creder = rgy.reger.creds.get(keys=(said,))
        if creder is None:
            return fail(f"credential {said} is not held here. Run ./scripts/sync.sh, then check "
                        f"./scripts/revoke-readiness.sh.")
        if creder.issuer != ghab.pre:
            return fail(f"credential {said} was issued by {creder.issuer}, not the group {ghab.pre}")
        regk = creder.regi
        et, dt = tel_state(rgy.reger, said, regk)
        if et == "rev":
            return fail(f"credential {said} is already revoked ({str(dt)[:19]})")
        if et is None:
            return fail(f"credential {said}: no TEL issuance for it here (registry {regk}). Run "
                        f"./scripts/sync.sh; if it still shows, its create never completed on any GAR.")
        with contextlib.redirect_stdout(sys.stderr):  # adopt's messages are for the operator, not the caller
            name = ensure_registered(rgy, ghab, args.alias, args.registry_name, regk)
        if name is None:
            return fail(f"registry {regk} of credential {said} cannot be registered here (see above)")
        if name != args.registry_name:
            print(f"credential {said} is in registry {regk}, registered here as {name!r} "
                  f"(not {args.registry_name!r}); revoking there", file=sys.stderr)
        print(name)
        return 0
    finally:
        hby.close()


if __name__ == "__main__":
    sys.exit(main())
