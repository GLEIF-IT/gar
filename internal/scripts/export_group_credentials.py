#!/usr/bin/env python3
"""
Export every credential the group AID has issued, as one CESR stream another
member's GAR can ingest with import-credential.sh, plus a JSON manifest.

The stream holds, in dependency order and each item once: the KELs of every
issuer (delegators before delegates), the group registry's management TEL, each
credential's TEL (issuance, and revocation if any), every chained credential
(e.g. the LE an OOR/ECR authorization points to, and the QVI credential behind
it) and the credentials themselves. This is what a member needs in its keystore
to take part in revoking a credential it did not help issue. Works for either
group: GLEIF Internal (OOR/ECR authorizations) or GLEIF External (QVI credentials).

The manifest lists each credential (SAID, type, TEL state, issuee) and the
registry, and carries the schemas the credentials use, so import-credential.sh
can load any a keystore lacks and revoke-readiness.sh can show which of these
credentials each GAR can revoke.

Usage (normally via export-group-credentials.sh):
  export_group_credentials.py --name <keystore> --passcode <bran> --alias <group alias>
                              --out <stream.cesr> --manifest <manifest.json>
"""
import argparse
import json
import sys

from keri.app import signing
from keri.app.cli.common import existing
from keri.app.habbing import GroupHab
from keri.core import serdering
from keri.help import helping
from keri.vdr import credentialing

from sent_exns import credential_state


# vLEI schema SAIDs -> short names; anything else falls back to the schema's title.
SCHEMAS = {
    "EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao": "QVI",
    "ENPXp1vQzRF6JwIuS-mp2U8Uf1MoADoP_GqQ62VsDZWY": "Legal Entity",
    "EKA57bKBKxr_kN7iN5i7lMUxpMG-s19dRcmov1iDxz-E": "OOR Authorization",
    "EH6ekLjSr8V32WyFbGe1zXjTzFs9PkTYmupJ9H65O14g": "ECR Authorization",
    "EBNaNu-M9P5cgrnfl2Fvymy4E_jvxxyjb70PRtiANlJy": "OOR",
    "EEy9PkikFcANV1l7EHukCeXqrzT1hNZjGlUk7wuMO5jw": "ECR",
}


def schema_name(hby, said):
    if said in SCHEMAS:
        return SCHEMAS[said]
    schemer = hby.db.schema.get(said)
    if schemer is not None and schemer.sed.get("title"):
        return schemer.sed["title"]
    return said


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--alias", "-a", required=True, help="alias of the issuing (group) AID")
    p.add_argument("--out", "-o", required=True, help="CESR stream to write")
    p.add_argument("--manifest", "-m", required=True, help="JSON manifest to write")
    return p.parse_args()


class Exporter:
    """Accumulates a deduplicated, dependency-ordered list of messages: KELs, TELs and credentials.

    .items holds (key, kind, raw) in send order; key is unique per message
    ("evt:<said>" for KEL/TEL events, "acdc:<said>" for credentials) so sync.py
    can skip what a recipient was already sent; kind is "kel", "tel" or "acdc".
    .stream is the same as one CESR stream.
    """

    def __init__(self, hby, reger):
        self.hby = hby
        self.reger = reger
        self.items = []
        self.kels = set()
        self.tels = set()
        self.creds = set()
        self.warnings = []

    @property
    def stream(self):
        return b"".join(raw for _, _, raw in self.items)

    def _events(self, msgs, kind):
        n = 0
        for msg in msgs:
            msg = bytes(msg)
            serder = serdering.SerderKERI(raw=msg)
            self.items.append((f"evt:{serder.said}", kind, msg))
            n += 1
        return n

    def kel(self, pre):
        if pre in self.kels:
            return
        self.kels.add(pre)
        try:
            kever = self.hby.kevers[pre]  # item lookup: .get() misses non-own AIDs
        except KeyError:
            kever = None
        if kever is not None and kever.delegator:
            self.kel(kever.delegator)  # a delegated KEL only verifies once its delegator's is in
        if self._events(self.hby.db.clonePreIter(pre=pre), "kel") == 0:
            self.warnings.append(f"no KEL held here for {pre}")

    def tel(self, pre):
        if pre in self.tels:
            return
        self.tels.add(pre)
        self._events(self.reger.clonePreIter(pre=pre), "tel")

    def cred(self, said):
        """Add a credential after its chain; False when it (or its anchor) is not held here."""
        if said in self.creds:
            return True
        self.creds.add(said)
        creder = self.reger.creds.get(keys=(said,))
        anchor = self.reger.cancs.get(keys=(said,))
        if creder is None or anchor is None:
            self.warnings.append(f"credential {said} not held here (body {creder is not None}, anchor {anchor is not None})")
            return False
        for key, edge in (creder.edge or {}).items():
            if key != "d" and isinstance(edge, dict) and "n" in edge:
                self.cred(edge["n"])
        self.kel(creder.issuer)
        if creder.regi is not None:
            self.tel(creder.regi)
            self.tel(creder.said)
        prefixer, seqner, saider = anchor
        self.items.append((f"acdc:{said}", "acdc", signing.serialize(creder, prefixer, seqner, saider)))
        return True


def group_credentials(reger, issuer):
    """SAIDs of every credential issued by `issuer` held here: saved ones plus any held but never saved."""
    saids = [s.qb64 for s in reger.issus.get(keys=issuer)]
    seen = set(saids)
    for _, creder in reger.creds.getItemIter():
        if creder.issuer == issuer and creder.said not in seen:
            saids.append(creder.said)
            seen.add(creder.said)
    return saids


def main():
    args = parse_args()
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        ghab = hby.habByName(args.alias)
        if ghab is None:
            print(f"alias {args.alias!r} not found in keystore {hby.name!r}", file=sys.stderr)
            return 2
        rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
        reger = rgy.reger
        ex = Exporter(hby, reger)
        ex.kel(ghab.pre)

        records, schemas, registries = [], {}, {}
        for said in group_credentials(reger, ghab.pre):
            if not ex.cred(said):
                continue
            creder = reger.creds.get(keys=(said,))
            a = creder.attrib if isinstance(creder.attrib, dict) else {}
            records.append({
                "said": said,
                "schema": creder.schema,
                "type": schema_name(hby, creder.schema),
                "registry": creder.regi,
                "state": credential_state(reger, said),
                "dt": a.get("dt"),
                "issuee": a.get("i"),
                "person": a.get("AID"),
                "personLegalName": a.get("personLegalName"),
                "role": a.get("officialRole") or a.get("engagementContextRole"),
            })
            if creder.regi:
                registries.setdefault(creder.regi, 0)
                registries[creder.regi] += 1
        # Schemas of everything in the stream, chained credentials included: a keystore
        # without one holds the credential in its missing-schema escrow.
        for said in ex.creds:
            creder = reger.creds.get(keys=(said,))
            if creder is not None and creder.schema not in schemas:
                schemer = hby.db.schema.get(creder.schema)
                if schemer is not None:
                    schemas[creder.schema] = schemer.raw.decode("utf-8")
                else:
                    ex.warnings.append(f"schema {creder.schema} not held here")

        local_names = {rec.registryKey: name for (name,), rec in reger.regs.getItemIter()}
        manifest = {
            "group": {"alias": args.alias, "pre": ghab.pre},
            "exportedBy": ghab.mhab.pre if isinstance(ghab, GroupHab) else None,
            "exportedAt": helping.nowIso8601(),
            "stream": {"bytes": len(ex.stream), "credentials": len(ex.creds), "kels": len(ex.kels)},
            "registries": [{"regk": regk, "credentials": n, "exporterName": local_names.get(regk)}
                           for regk, n in registries.items()],
            "credentials": sorted(records, key=lambda r: r["dt"] or ""),
            "schemas": schemas,
        }
        stream = ex.stream
        with open(args.out, "wb") as f:
            f.write(stream)
        with open(args.manifest, "w") as f:
            json.dump(manifest, f, indent=2)

        revoked = sum(1 for r in records if r["state"].startswith("revoked"))
        print(f"group {args.alias} ({ghab.pre})")
        print(f"  {len(records)} credential(s) issued by the group ({revoked} revoked), "
              f"{len(ex.creds) - len(records)} chained credential(s), {len(ex.kels)} KEL(s), {len(schemas)} schema(s)")
        for reg in manifest["registries"]:
            print(f"  registry {reg['regk']}  {reg['credentials']} credential(s)  (named {reg['exporterName']!r} here)")
        for w in ex.warnings:
            print(f"  warning: {w}")
        return 0
    finally:
        hby.close()


if __name__ == "__main__":
    sys.exit(main())
