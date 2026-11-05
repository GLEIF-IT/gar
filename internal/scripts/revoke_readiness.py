#!/usr/bin/env python3
"""
Show, for every credential the group AID has issued, whether THIS keystore can
take part in revoking it, and what it is missing if not.

`kli vc revoke` and the revoke branch of `kli multisig join` build the TEL rev
event locally, so a member needs: the group registry registered under the
registry name the scripts pass (adopt-registry.sh), the credential's TEL
issuance event, and the credential body. Join also shows the schema title, so
it needs the schema. A revoke needs two members (5 members at 1/2 each) that
both have all of these.

With --manifest (from export-group-credentials.sh on another GAR) the list is
the exporter's credentials plus any held only here, and each is marked when it
is missing from one side, which shows what an import would bring and what the
exporter itself lacks.

Usage (normally via revoke-readiness.sh):
  revoke_readiness.py --name <keystore> --passcode <bran> --alias <group alias>
                      --registry-name <name> [--manifest <manifest.json>] [--all] [--json]
"""
import argparse
import json
import sys

from keri.app.cli.common import existing
from keri.vdr import credentialing

from export_group_credentials import group_credentials, schema_name


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--alias", "-a", required=True, help="alias of the group AID")
    p.add_argument("--registry-name", "-r", required=True, help="registry name the revoke scripts pass")
    p.add_argument("--manifest", "-m", default=None, help="manifest from export-group-credentials.sh")
    p.add_argument("--all", action="store_true", help="list every credential, not only those not revocable here")
    p.add_argument("--json", "-j", action="store_true", help="emit one JSON object instead of text (for jq)")
    return p.parse_args()


def tel_state(reger, said, regk):
    """('iss'|'rev'|None, dt) from this keystore's TEL for the credential."""
    if not regk:
        return None, None
    try:
        tever = reger.tevers[regk]  # lazy table: only item lookup loads a registry
    except KeyError:
        return None, None
    state = tever.vcState(vci=said)
    if state is None:
        return None, None
    et = state.et if hasattr(state, "et") else state.ked.get("et")
    dt = state.dt if hasattr(state, "dt") else state.ked.get("dt")
    return {"iss": "iss", "bis": "iss", "rev": "rev", "brv": "rev"}.get(et, et), dt


def assess(hby, rgy, said, adopted, listed):
    reger = rgy.reger
    creder = reger.creds.get(keys=(said,))
    regk = creder.regi if creder is not None else (listed or {}).get("registry")
    schema = creder.schema if creder is not None else (listed or {}).get("schema")
    et, dt = tel_state(reger, said, regk)
    missing = []
    if creder is None:
        missing.append("credential body")
    if et is None:
        missing.append("TEL issuance")
    if adopted is None:
        missing.append("registry not adopted")
    elif regk and regk != adopted:
        missing.append(f"credential is in registry {regk}, not the adopted one")
    never = et is None and listed and str(listed.get("state", "")).startswith("no TEL")
    if et == "rev":
        verdict = "revoked"
    elif never:
        verdict = "never issued"
        missing = []
    elif missing:
        verdict = "cannot revoke"
    else:
        verdict = "can revoke"
    notes = []
    if never:
        notes.append("the exporter has no TEL issuance either: its create never completed, nothing to revoke")
    if schema and hby.db.schema.get(schema) is None:
        notes.append("schema missing (kli multisig join needs it)")
    if listed is None and creder is not None:
        notes.append("not in the manifest: the exporter does not hold it")
    rec = listed or {}
    return {
        "said": said,
        "type": schema_name(hby, schema) if schema else "?",
        "verdict": verdict,
        "missing": missing,
        "notes": notes,
        "saved": reger.saved.get(keys=said) is not None,
        "tel": {"iss": "issued", "rev": "revoked"}.get(et, "none") + (f" {str(dt)[:19]}" if dt else ""),
        "personLegalName": rec.get("personLegalName") or (creder.attrib.get("personLegalName") if creder else None),
        "role": rec.get("role") or (creder and (creder.attrib.get("officialRole") or creder.attrib.get("engagementContextRole"))),
        "dt": rec.get("dt") or (creder.attrib.get("dt") if creder else None),
    }


def collect(hby, rgy, ghab, registry_name, manifest=None):
    """(rows, counts by verdict, adopted registry prefix or None) for every group credential known here."""
    regrec = rgy.reger.regs.get(keys=registry_name)
    adopted = regrec.registryKey if regrec is not None and regrec.registryKey in rgy.regs else None
    listed = {c["said"]: c for c in manifest.get("credentials", [])} if manifest else {}
    saids = list(listed)
    saids += [s for s in group_credentials(rgy.reger, ghab.pre) if s not in listed]
    rows = [assess(hby, rgy, s, adopted, listed.get(s) if manifest else {}) for s in saids]
    rows.sort(key=lambda r: r["dt"] or "")
    counts = {}
    for r in rows:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    return rows, counts, adopted


def main():
    args = parse_args()
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        ghab = hby.habByName(args.alias)
        if ghab is None:
            print(f"alias {args.alias!r} not found in keystore {hby.name!r}", file=sys.stderr)
            return 2
        rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
        manifest = None
        if args.manifest:
            with open(args.manifest) as f:
                manifest = json.load(f)
            if manifest.get("group", {}).get("pre") != ghab.pre:
                print(f"manifest is for group {manifest.get('group', {}).get('pre')}, not {ghab.pre}", file=sys.stderr)
                return 2
        rows, counts, adopted = collect(hby, rgy, ghab, args.registry_name, manifest)
        listed = {c["said"]: c for c in manifest.get("credentials", [])} if manifest else {}
        if args.json:
            print(json.dumps({"group": ghab.pre, "registryName": args.registry_name, "adoptedRegistry": adopted,
                              "counts": counts, "credentials": rows}, indent=2))
            return 0

        print()
        print(f"Group: {args.alias} ({ghab.pre})")
        print(f"Registry {args.registry_name!r}: {adopted or 'NOT registered here (run adopt-registry.sh)'}")
        if manifest:
            print(f"Manifest: {len(listed)} credential(s), exported {manifest.get('exportedAt', '?')[:19]}"
                  f" by {manifest.get('exportedBy') or '?'}")
        summary = ", ".join(f"{n} {v}" for v, n in sorted(counts.items()))
        print(f"{len(rows)} credential(s){': ' + summary if summary else ''}")
        if not manifest:
            print("Without a manifest this only checks credentials this keystore already knows about; ones it never "
                  "received are not listed. Run it with the manifest from export-group-credentials.sh to check "
                  "against everything the group issued.")
        if adopted is None:
            print(f"This keystore cannot revoke (or create) anything until the group registry is registered as "
                  f"{args.registry_name!r}: import the export, then run adopt-registry.sh <manifest>.")
        shown = [r for r in rows if args.all or r["verdict"] == "cannot revoke" or r["notes"]]
        if not shown and rows and adopted is not None:
            print("every listed credential not already revoked can be revoked from this keystore")
        for r in shown:
            print()
            print(f"  {r['said']}  {r['type']}  [{r['verdict']}]  TEL {r['tel']}")
            detail = [d for d in (r["personLegalName"], r["role"], f"issued {r['dt'][:19]}" if r["dt"] else None) if d]
            if detail:
                print("      " + "  |  ".join(detail))
            if r["missing"]:
                print("      missing: " + ", ".join(r["missing"]))
            for n in r["notes"]:
                print("      note: " + n)
        if counts.get("cannot revoke"):
            print()
            print("To fix: on a GAR that holds them, export-group-credentials.sh; here, import-credential.sh "
                  "<stream> <manifest>, then adopt-registry.sh <manifest> if the registry is not registered.")
        return 0
    finally:
        hby.close()


if __name__ == "__main__":
    sys.exit(main())
