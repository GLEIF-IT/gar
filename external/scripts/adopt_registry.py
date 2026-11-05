#!/usr/bin/env python3
"""
Register the group's existing credential registry in this keystore, under the
local registry name the create/grant/revoke scripts use (INT_GAR_REG_NAME or
EXT_GAR_REG_NAME).

A GAR that joined the group after the registry was incepted (or never took part
in the inception) has no local record tying a registry name to the group
registry, so `kli vc create` and `kli vc revoke --registry-name ...` fail with
"invalid registry name". `kli vc registry incept` would make a NEW registry with
a different prefix: existing credentials name the original one in their `ri`
field and can only be revoked in its TEL, and the group must issue into a single
registry, so a member has to adopt the original instead.

Adopting writes one local record (name -> registry prefix, group AID): the same
record `kli multisig join` writes when a member approves the registry inception.
Nothing is signed or sent. The registry's TEL must already be here, from
import-credential.sh with a stream from export-group-credentials.sh; this
checks it is, and that the registry's issuer is the group AID.

Usage (normally via adopt-registry.sh):
  adopt_registry.py --name <keystore> --passcode <bran> --alias <group alias>
                    --registry-name <name> [--manifest <manifest.json> | --regk <prefix>]
"""
import argparse
import json
import sys

from keri.app.cli.common import existing
from keri.app.habbing import GroupHab
from keri.vdr import credentialing, viring


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--alias", "-a", required=True, help="alias of the group AID")
    p.add_argument("--registry-name", "-r", required=True, help="local name to register it under")
    p.add_argument("--manifest", "-m", default=None, help="manifest from export-group-credentials.sh")
    p.add_argument("--regk", default=None, help="registry prefix, if not taken from the manifest")
    return p.parse_args()


def candidate_registries(args, reger, group):
    """Registry prefixes to adopt: the manifest's, --regk, or those named by credentials the group issued here."""
    if args.regk:
        return [args.regk], "--regk"
    if args.manifest:
        with open(args.manifest) as f:
            manifest = json.load(f)
        if manifest.get("group", {}).get("pre") != group:
            raise SystemExit(f"manifest is for group {manifest.get('group', {}).get('pre')}, not {group}")
        return [r["regk"] for r in manifest.get("registries", [])], "the manifest"
    return group_registries(reger, group), "credentials the group issued held here"


def group_registries(reger, group):
    """Registry prefixes named by the credentials held here that the group issued."""
    regks = []
    for _, creder in reger.creds.getItemIter():
        if creder.issuer == group and creder.regi and creder.regi not in regks:
            regks.append(creder.regi)
    return regks


def main():
    args = parse_args()
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        ghab = hby.habByName(args.alias)
        if ghab is None:
            print(f"alias {args.alias!r} not found in keystore {hby.name!r}", file=sys.stderr)
            return 2
        if not isinstance(ghab, GroupHab):
            print(f"{args.alias!r} is not a group AID here", file=sys.stderr)
            return 2
        rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
        reger = rgy.reger

        regks, source = candidate_registries(args, reger, ghab.pre)
        return adopt(rgy, ghab, args.alias, args.registry_name, regks, source)
    finally:
        hby.close()


def adopt(rgy, ghab, alias, registry_name, regks, source):
    """Register the one registry in `regks` as `registry_name`; returns a process exit code."""
    reger = rgy.reger
    if len(regks) != 1:
        print(f"expected one registry from {source}, found {len(regks)}: {', '.join(regks) or '-'}"
              f"{'; pass --regk' if regks else ''}", file=sys.stderr)
        return 2
    regk = regks[0]

    try:
        tever = reger.tevers[regk]  # lazy table: only item lookup loads a registry
    except KeyError:
        print(f"registry {regk}: no TEL held here. Run import-credential.sh with the stream from "
              f"export-group-credentials.sh first.", file=sys.stderr)
        return 1
    if tever.pre != ghab.pre:
        print(f"registry {regk} was incepted by {tever.pre}, not the group {ghab.pre}; not adopting",
              file=sys.stderr)
        return 1

    existing_rec = reger.regs.get(keys=registry_name)
    if existing_rec is not None:
        if existing_rec.registryKey == regk:
            print(f"registry {regk} is already registered here as {registry_name!r}; nothing to do")
            return report(rgy, registry_name)
        print(f"the name {registry_name!r} is already registered here for a different registry "
              f"{existing_rec.registryKey}; not overwriting", file=sys.stderr)
        return 1
    for (name,), rec in reger.regs.getItemIter():
        if rec.registryKey == regk:
            print(f"registry {regk} is already registered here as {name!r}. Set the registry name in "
                  f"~/.gar/internal.sh or external.sh (INT_GAR_REG_NAME / EXT_GAR_REG_NAME) to that name instead of "
                  f"adding a second one.", file=sys.stderr)
            return 1

    reger.regs.put(keys=registry_name, val=viring.RegistryRecord(registryKey=regk, prefix=ghab.pre))
    rgy.loadRegistries()
    print(f"registered registry {regk} (group {alias}, {ghab.pre}) as {registry_name!r}")
    return report(rgy, registry_name)


def report(rgy, name):
    registry = rgy.registryByName(name)
    if registry is None:
        print(f"  but {name!r} does not load as a registry", file=sys.stderr)
        return 1
    tever = registry.tever
    print(f"  TEL sn {registry.regi}, {'no backers' if tever.noBackers else 'backers ' + ', '.join(tever.baks)}"
          f"{', establishment only' if registry.estOnly else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
