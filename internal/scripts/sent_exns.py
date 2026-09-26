#!/usr/bin/env python3
"""
List the exchange messages (exns) this keystore's AIDs have SENT, such as IPEX
credential grants, and what came back for each.

Outgoing exns are not sitting in your own mailbox: the sender pushes them to the
recipient's mailbox, and the recipient's mailbox cannot be read by anyone else.
What this keystore keeps is its own record of every exn that was fully signed
here (for the group AID, that means every grant the members completed, whether
or not you were the member who delivered it), plus every reply that arrived in
your mailboxes. So this script:

  1. optionally polls your mailboxes first (--poll), on the same topics
     `kli ipex list --poll` uses, so new admits are pulled in;
  2. walks the local exn table and prints each exn sent by one of your AIDs:
     when, route, sender, recipient, SAID; for a grant the credential SAID,
     schema and issuee and the credential's registry state; for a group AID
     how many member signatures it carries, whether that meets the threshold,
     and which member was lead (the lead is the one that sent it to the
     recipient); and the reply (e.g. the admit) if one was received.

Usage (normally via sent-exns.sh):
  sent_exns.py --name <keystore> --passcode <bran> [--poll SECONDS] [--route /ipex/grant]
               [--alias <sender alias>] [--received] [--verbose] [--json]

--json prints one JSON array of records (dt, route, direction, said, from, to,
credential, signatures, delivered_by, reply, and with --verbose the body) for jq.
"""
import argparse
import datetime
import json
import sys

from hio.base import doing

from keri.app import connecting, indirecting, notifying
from keri.app.cli.common import existing
from keri.core import coring, eventing
from keri.help import helping
from keri.peer import exchanging
from keri.vc import protocoling
from keri.vdr import credentialing, verifying


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--poll", type=float, default=0, metavar="SECONDS",
                   help="poll your mailboxes for this long first (topics /credential /replay /reply)")
    p.add_argument("--route", "-r", default=None, help="only routes starting with this, e.g. /ipex/grant")
    p.add_argument("--alias", "-a", default=None, help="only exns sent by this local alias")
    p.add_argument("--received", action="store_true", help="also list exns received from others")
    p.add_argument("--verbose", "-V", action="store_true", help="print the full JSON body of each exn")
    p.add_argument("--json", "-j", action="store_true", help="emit JSON records instead of text (for jq)")
    return p.parse_args()


def poll(hby, seconds):
    notifier = notifying.Notifier(hby=hby)
    rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
    vry = verifying.Verifier(hby=hby, reger=rgy.reger)
    exc = exchanging.Exchanger(hby=hby, handlers=[])
    protocoling.loadHandlers(hby, exc, notifier)
    mbx = indirecting.MailboxDirector(hby=hby, topics=["/credential", "/replay", "/reply"], exc=exc, verifier=vry)
    sys.stdout.write(f"Checking mailboxes for {seconds:.0f}s")
    sys.stdout.flush()

    class Tick(doing.Doer):
        def recur(self, tyme):
            sys.stdout.write(".")
            sys.stdout.flush()
            return False

    doing.Doist(limit=seconds, tock=1.0, real=True).do(doers=[mbx, Tick()])
    print()


def alias_of(hby, org, pre):
    """Alias for pre: a local hab name, else a contact alias, else None."""
    if pre in hby.habs:
        return hby.habs[pre].name
    c = org.get(pre)
    if c and c.get("alias"):
        return c["alias"]
    return None


def who(hby, org, pre):
    """'alias (pre)' for text output, or just the prefix when no alias is known."""
    alias = alias_of(hby, org, pre)
    return f"{alias} ({pre})" if alias else pre


def party(hby, org, pre):
    """{'alias': ..., 'pre': ...} for JSON output."""
    return {"alias": alias_of(hby, org, pre), "pre": pre}


def credential_state(reger, said):
    """'issued' / 'revoked' / 'unknown' for a credential SAID held in this keystore's registries."""
    try:
        creder = reger.creds.get(keys=(said,))
        if creder is None:
            return "not held here"
        try:
            tever = reger.tevers[creder.sad.get("ri")]  # lazy table: only item lookup loads a registry
        except KeyError:
            return "registry not held here"
        state = tever.vcState(vci=said)
        if state is None:
            return "no TEL event for this credential here"
        et = state.et if hasattr(state, "et") else state.ked.get("et")
        dt = state.dt if hasattr(state, "dt") else state.ked.get("dt", "")
        word = {"iss": "issued", "bis": "issued", "rev": "revoked", "brv": "revoked"}.get(et, str(et))
        return f"{word} {str(dt)[:19]}"
    except Exception as ex:  # any registry problem is reported, never fatal
        return f"registry error: {ex}"


def main():
    args = parse_args()
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        if args.poll:
            poll(hby, args.poll)
        return report(hby, args)
    finally:
        hby.close()


def report(hby, args):
    db = hby.db
    org = connecting.Organizer(hby=hby)
    rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
    exc = exchanging.Exchanger(hby=hby, handlers=[])

    only = None
    if args.alias:
        hab = hby.habByName(args.alias)
        if hab is None:
            print(f"alias {args.alias!r} not found in keystore {hby.name!r}", file=sys.stderr)
            return 2
        only = hab.pre

    rows = []
    for (said,), serder in db.exns.getItemIter():
        ked = serder.ked
        sent = ked["i"] in hby.prefixes
        if not sent and not args.received:
            continue
        if only and ked["i"] != only:
            continue
        if args.route and not ked["r"].startswith(args.route):
            continue
        rows.append((ked.get("dt", ""), sent, serder))
    rows.sort(key=lambda r: r[0])

    records = [describe(hby, org, rgy, exc, dt, sent, serder, args.verbose) for dt, sent, serder in rows]

    if args.json:
        print(json.dumps(records, indent=2))
        return 0

    if not records:
        print("no matching exchange messages in this keystore")
        return 0

    for rec in records:
        render(rec)
    print()
    print(f"{len(records)} message(s)")
    return 0


def describe(hby, org, rgy, exc, dt, sent, serder, verbose):
    """One structured record for an exn."""
    ked = serder.ked
    attrs = ked.get("a") if isinstance(ked.get("a"), dict) else {}
    recipient = attrs.get("i") or ked.get("rp") or None
    rec = {
        "dt": dt,
        "route": ked["r"],
        "direction": "sent" if sent else "received",
        "said": serder.said,
        "from": party(hby, org, ked["i"]),
        "to": party(hby, org, recipient) if recipient else None,
        "credential": None,
        "signatures": None,
        "delivered_by": None,
        "reply": None,
    }

    embeds = ked.get("e") if isinstance(ked.get("e"), dict) else {}
    acdc = embeds.get("acdc")
    if isinstance(acdc, dict):
        issuee = acdc.get("a", {}).get("i") if isinstance(acdc.get("a"), dict) else None
        rec["credential"] = {
            "said": acdc.get("d"),
            "schema": acdc.get("s"),
            "registry": acdc.get("ri"),
            "issuee": party(hby, org, issuee) if issuee else None,
            "state": credential_state(rgy.reger, acdc.get("d")),
        }

    hab = hby.habs.get(ked["i"]) if sent else None
    if hab is not None and hasattr(hab, "mhab"):  # group AID: who signed, who delivered
        tsgs = eventing.fetchTsgs(hby.db.esigs, coring.Saider(qb64=serder.said))
        sigers = tsgs[0][3] if tsgs else []
        members = hab.smids
        rec["signatures"] = {
            "count": len(sigers),
            "members": len(members),
            "threshold": hab.kever.tholder.sith,
            "signed_by": [party(hby, org, members[s.index]) if s.index < len(members) else {"alias": None, "pre": None, "index": s.index}
                          for s in sigers],
        }
        if sigers:
            # The lead (lowest signing index among the signers) is the member that sent it.
            keys = [v.qb64 for v in hab.kever.verfers]
            windex = min(s.index for s in sigers)
            leader = next((m for m in members if hby.kevers[m].verfers[0].qb64 == keys[windex]), None) \
                if windex < len(keys) else None
            rec["delivered_by"] = {"me": bool(exc.lead(hab, serder.said)),
                                   **(party(hby, org, leader) if leader else {"alias": None, "pre": None})}

    reply = hby.db.erpy.get(keys=(serder.said,))
    if reply is not None:
        rserder = hby.db.exns.get(keys=(reply.qb64,))
        if rserder is not None:
            rec["reply"] = {"route": rserder.ked["r"], "dt": rserder.ked.get("dt"),
                            "from": party(hby, org, rserder.ked["i"]), "said": rserder.said}
        else:
            rec["reply"] = {"route": None, "dt": None, "from": None, "said": reply.qb64}

    if verbose:
        rec["body"] = ked
    return rec


def render(rec):
    """Text rendering of one record."""
    def name(p):
        return f"{p['alias']} ({p['pre']})" if p and p.get("alias") else (p or {}).get("pre") or "?"

    print()
    print(f"{(rec['dt'] or '')[:19]}  {rec['route']:<20}  {'SENT' if rec['direction'] == 'sent' else 'received'}  {rec['said']}")
    print(f"    from  {name(rec['from'])}")
    if rec["to"]:
        print(f"    to    {name(rec['to'])}")
    cred = rec["credential"]
    if cred:
        print(f"    credential  {cred['said']}")
        print(f"      schema    {cred['schema']}")
        if cred["issuee"]:
            print(f"      issuee    {name(cred['issuee'])}")
        print(f"      state     {cred['state']}")
    sigs = rec["signatures"]
    if sigs:
        print(f"    signatures  {sigs['count']} of {sigs['members']} members (threshold {sigs['threshold']!r})")
        for p in sigs["signed_by"]:
            print(f"      {name(p)}")
    lead = rec["delivered_by"]
    if lead:
        print(f"    delivered by  {'this member' if lead['me'] else name(lead)}")
    reply = rec["reply"]
    if reply:
        if reply["route"]:
            print(f"    reply  {reply['route']}  {(reply['dt'] or '')[:19]}  from {name(reply['from'])}  {reply['said']}")
        else:
            print(f"    reply  {reply['said']} (body not held)")
    elif rec["direction"] == "sent" and rec["route"] == "/ipex/grant":
        print("    reply  none received yet (no admit)")
    if "body" in rec:
        body = json.dumps(rec["body"], indent=2)
        print("    body")
        print("      " + body.replace("\n", "\n      "))


if __name__ == "__main__":
    sys.exit(main())
