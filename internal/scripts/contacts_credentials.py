#!/usr/bin/env python3
"""
Compare the contacts in this keystore with the credentials the group AID has
issued: for every contact, which credentials name it and whether the IPEX grant
that delivers each one was sent and admitted.

A contact is matched to a credential two ways:
  issuee   the credential was issued TO the contact (attribute `i`), e.g. a QVI
           holding an OOR/ECR Authorization credential;
  subject  the credential is ABOUT the contact (attribute `AID`), e.g. the person
           an OOR/ECR Authorization credential authorizes a QVI to issue to.

Everything is read from the local keystore: contacts and their challenge state
(what `kli contacts list` shows), the credentials indexed as issued by the group
AID with their registry (TEL) state, and the keystore's own record of every
/ipex/grant exn it fully signed plus the admit if one arrived (as sent_exns.py).
--poll checks your mailboxes first so new admits are pulled in.

Usage (normally via contacts-credentials.sh):
  contacts_credentials.py --name <keystore> --passcode <bran> --alias <group alias>
                          [--poll SECONDS] [--contact <alias or AID>]... [--skip-empty] [--json]

--json prints one JSON object: {"issuer": ..., "contacts": [...], "unmatched": [...]}.
"""
import argparse
import json
import sys
from collections import defaultdict

from keri.app import connecting
from keri.app.cli.common import existing
from keri.vdr import credentialing

# Same directory (mounted at /scripts in the container): mailbox polling,
# registry state lookup and alias resolution are shared with sent-exns.sh.
from sent_exns import credential_state, party, poll

# Short names for the vLEI schemas this repository issues or chains to; any other
# schema falls back to the title stored with it, then to its SAID.
SCHEMAS = {
    "EKA57bKBKxr_kN7iN5i7lMUxpMG-s19dRcmov1iDxz-E": "OOR Authorization",
    "EH6ekLjSr8V32WyFbGe1zXjTzFs9PkTYmupJ9H65O14g": "ECR Authorization",
    "EEy9PkikFcANV1l7EHukCeXqrzT1hNZjGlUk7wuMO5jw": "ECR",
    "EBNaNu-M9P5cgrnfl2Fvymy4E_jvxxyjb70PRtiANlJy": "OOR",
    "ENPXp1vQzRF6JwIuS-mp2U8Uf1MoADoP_GqQ62VsDZWY": "Legal Entity",
}


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--alias", "-a", required=True, help="alias of the issuing (group) AID")
    p.add_argument("--poll", type=float, default=0, metavar="SECONDS",
                   help="poll your mailboxes for this long first (topics /credential /replay /reply)")
    p.add_argument("--contact", "-c", action="append", default=None, metavar="ALIAS_OR_AID",
                   help="only this contact (alias or AID); repeatable")
    p.add_argument("--skip-empty", action="store_true", help="hide contacts with no credentials")
    p.add_argument("--json", "-j", action="store_true", help="emit one JSON object instead of text (for jq)")
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
        return report(hby, hab, args)
    finally:
        hby.close()


def authenticated(hby, aid):
    """True when a challenge we generated for aid came back signed by aid (what contacts.sh shows)."""
    accepted = {s.qb64 for s in hby.db.chas.get(keys=(aid,))}
    received = {s.qb64 for s in hby.db.reps.get(keys=(aid,))}
    return bool(accepted & received)


def schema_name(hby, said):
    if said in SCHEMAS:
        return SCHEMAS[said]
    schemer = hby.db.schema.get(said)
    if schemer is not None and schemer.sed.get("title"):
        return schemer.sed["title"]
    return said


def grants_by_credential(hby, org, issuer):
    """{credential SAID: [grant record, ...]} for every /ipex/grant exn the issuer sent."""
    db = hby.db
    out = defaultdict(list)
    for (said,), serder in db.exns.getItemIter():
        ked = serder.ked
        if ked.get("r") != "/ipex/grant" or ked.get("i") != issuer:
            continue
        embeds = ked.get("e") if isinstance(ked.get("e"), dict) else {}
        acdc = embeds.get("acdc")
        if not isinstance(acdc, dict) or not acdc.get("d"):
            continue
        attrs = ked.get("a") if isinstance(ked.get("a"), dict) else {}
        recipient = attrs.get("i") or ked.get("rp") or None
        rec = {"said": serder.said, "dt": ked.get("dt"),
               "to": party(hby, org, recipient) if recipient else None, "reply": None}
        reply = db.erpy.get(keys=(serder.said,))
        if reply is not None:
            rserder = db.exns.get(keys=(reply.qb64,))
            if rserder is not None:
                rec["reply"] = {"route": rserder.ked["r"], "dt": rserder.ked.get("dt"),
                                "from": party(hby, org, rserder.ked["i"]), "said": rserder.said}
            else:
                rec["reply"] = {"route": None, "dt": None, "from": None, "said": reply.qb64}
        out[acdc["d"]].append(rec)
    for recs in out.values():
        recs.sort(key=lambda r: r["dt"] or "")
    return out


def issued_credentials(hby, org, rgy, issuer, grants):
    """One record per credential the issuer AID has issued, oldest first."""
    reger = rgy.reger
    creds = []
    for saider in reger.issus.get(keys=issuer):
        creder = reger.creds.get(keys=(saider.qb64,))
        if creder is None:
            creds.append({"said": saider.qb64, "schema": None, "type": "(credential body not held here)",
                          "status": "unknown", "issuee": None, "person": None, "LEI": None,
                          "personLegalName": None, "role": None, "dt": None, "grants": grants.get(saider.qb64, [])})
            continue
        sad = creder.sad
        a = sad.get("a") if isinstance(sad.get("a"), dict) else {}
        issuee = a.get("i")
        person = a.get("AID")
        creds.append({
            "said": sad["d"],
            "schema": sad.get("s"),
            "type": schema_name(hby, sad.get("s")),
            "status": credential_state(reger, sad["d"]),
            "issuee": party(hby, org, issuee) if issuee else None,
            "person": party(hby, org, person) if person else None,
            "LEI": a.get("LEI"),
            "personLegalName": a.get("personLegalName"),
            "role": a.get("officialRole") or a.get("engagementContextRole"),
            "dt": a.get("dt"),
            "grants": grants.get(sad["d"], []),
        })
    creds.sort(key=lambda c: c["dt"] or "")
    return creds


def report(hby, hab, args):
    org = connecting.Organizer(hby=hby)
    rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)

    grants = grants_by_credential(hby, org, hab.pre)
    creds = issued_credentials(hby, org, rgy, hab.pre, grants)

    # credential SAID -> {aid: role}; a credential naming the same AID as both
    # issuee and subject is listed once, as issuee.
    by_aid = defaultdict(list)
    for cred in creds:
        issuee = (cred["issuee"] or {}).get("pre")
        person = (cred["person"] or {}).get("pre")
        if issuee:
            by_aid[issuee].append({"as": "issuee", **cred})
        if person and person != issuee:
            by_aid[person].append({"as": "subject", **cred})

    contacts = []
    wanted = set(args.contact or [])
    for c in sorted(org.list(), key=lambda c: (c.get("alias") or "").lower()):
        aid = c["id"]
        alias = c.get("alias")
        if wanted and alias not in wanted and aid not in wanted:
            continue
        matched = by_aid.pop(aid, [])
        if args.skip_empty and not matched:
            continue
        contacts.append({"alias": alias, "aid": aid, "authenticated": authenticated(hby, aid),
                         "credentials": matched})

    if wanted:
        missing = wanted - {c["alias"] for c in contacts} - {c["aid"] for c in contacts}
        for m in sorted(missing):
            print(f"warning: {m!r} is not a contact in keystore {hby.name!r}", file=sys.stderr)

    # Credentials that name none of the (selected) contacts.
    listed = {c["aid"] for c in contacts}
    unmatched = [cred for cred in creds
                 if not ({(cred["issuee"] or {}).get("pre"), (cred["person"] or {}).get("pre")} & listed)]

    out = {"issuer": {"alias": hab.name, "pre": hab.pre}, "contacts": contacts, "unmatched": unmatched}
    if args.json:
        print(json.dumps(out, indent=2))
        return 0
    render(out, filtered=bool(wanted))
    return 0


def render(out, filtered):
    def name(p):
        return f"{p['alias']} ({p['pre']})" if p and p.get("alias") else (p or {}).get("pre") or "?"

    def cred_lines(cred, indent, contact_aid=None):
        print(f"{indent}{cred['said']}  {cred['type']}  [{cred['status']}]")
        parts = []
        if cred["issuee"]:
            who = "this contact" if cred["issuee"]["pre"] == contact_aid else name(cred["issuee"])
            parts.append(f"issuee {who}")
        if cred["person"]:
            who = "this contact" if cred["person"]["pre"] == contact_aid else name(cred["person"])
            parts.append(f"person {who}")
        print(f"{indent}    " + "  |  ".join(parts))
        detail = [cred["personLegalName"], cred["role"], f"LEI {cred['LEI']}" if cred["LEI"] else None,
                  f"issued {cred['dt'][:19]}" if cred["dt"] else None]
        detail = [d for d in detail if d]
        if detail:
            print(f"{indent}    " + "  |  ".join(detail))
        if not cred["grants"]:
            print(f"{indent}    grant   none sent")
        for g in cred["grants"]:
            to = f"  ->  {name(g['to'])}" if g["to"] else ""
            print(f"{indent}    grant   {g['said']}  {(g['dt'] or '')[:19]}{to}")
            r = g["reply"]
            if r is None:
                print(f"{indent}            no admit received yet")
            elif r["route"]:
                print(f"{indent}            {r['route']}  {(r['dt'] or '')[:19]}  from {name(r['from'])}  {r['said']}")
            else:
                print(f"{indent}            reply {r['said']} (body not held)")

    print()
    print(f"Issuer: {out['issuer']['alias']} ({out['issuer']['pre']})")
    for c in out["contacts"]:
        print()
        print(f"Alias: {c['alias'] or '-'}")
        print(f"AID:   {c['aid']}")
        print(f"Authenticated: {c['authenticated']}")
        n = len(c["credentials"])
        print(f"Credentials: {n if n else 'none'}")
        for cred in c["credentials"]:
            print(f"  as {cred['as']}")
            cred_lines(cred, "    ", contact_aid=c["aid"])

    print()
    total = sum(len(c["credentials"]) for c in out["contacts"])
    print(f"{len(out['contacts'])} contact(s), {total} credential match(es)")
    if out["unmatched"]:
        label = "selected contact" if filtered else "contact"
        print()
        print(f"{len(out['unmatched'])} issued credential(s) name no {label}:")
        for cred in out["unmatched"]:
            cred_lines(cred, "  ")


if __name__ == "__main__":
    sys.exit(main())
