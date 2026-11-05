#!/usr/bin/env python3
"""
Catch this GAR up with the rest of the group, and the rest of the group up
with this GAR, over the members' KERI mailboxes. Run it at the start of every
session, after `source ./source.sh`.

  1. pull:   polls this keystore's mailboxes (topics /credential /replay /reply,
             the same intake `kli ipex list --poll` uses) and ingests any group
             credentials, their TELs, chains and KELs other members pushed here.
  2. adopt:  registers every group registry the held credentials name that
             has no local name yet (a GAR that joined after the registry was
             incepted), as adopt-registry.sh does: under the registry name if
             it is free, else "<registry name> <first 8 of the prefix>".
  3. push:   sends every member of the group the group-issued credentials this
             keystore holds that the member did not sign itself (a signer holds
             the credential already), with everything needed to verify them (KELs,
             registry and credential TELs, LE/QVI chain), as /fwd messages to
             one of each member's witnesses on the /credential topic: the same
             route `kli ipex grant` uses to deliver a credential chain to the
             QVI. A local record (~/.gar/sync/) of what reached each member
             keeps later runs to what is new, including new revocations.
  4. report: what this keystore can revoke now (revoke-readiness.sh).

Nothing is signed except the /fwd envelopes (by this GAR's member AID), and
nothing is added to any KEL or TEL. Recipients verify everything they receive.

Usage (normally via sync.sh):
  sync.py --name <keystore> --passcode <bran> --alias <group alias> --registry-name <name>
          [--poll SECONDS] [--no-pull] [--no-push] [--full] [--dry-run] [--to AID ...]
"""
import argparse
import json
import os
import sys

from hio.base import doing

from keri import kering
from keri.app import connecting, forwarding
from keri.app.cli.common import existing
from keri.app.habbing import GroupHab
from keri.core import coring, serdering
from keri.db.dbing import dgKey, snKey
from keri.vdr import credentialing

from adopt_registry import ensure_registered, group_registries, registered_names
from export_group_credentials import Exporter, group_credentials
from revoke_readiness import collect
from sent_exns import alias_of, poll

CHUNK = 64 * 1024  # bytes of messages per HTTP PUT to a witness; grants with a full chain are ~30 KB
SEND_TIMEOUT = 60.0


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--alias", "-a", required=True, help="alias of the group AID")
    p.add_argument("--registry-name", "-r", required=True, help="registry name the create/revoke scripts pass")
    p.add_argument("--poll", type=float, default=20, metavar="SECONDS", help="how long to poll mailboxes (default 20)")
    p.add_argument("--no-pull", action="store_true", help="skip polling")
    p.add_argument("--no-push", action="store_true", help="skip sending to the other members")
    p.add_argument("--full", action="store_true",
                   help="resend everything, ignoring what was sent before and who signed what")
    p.add_argument("--dry-run", action="store_true", help="show what would be sent; send nothing")
    p.add_argument("--to", action="append", metavar="AID", help="push only to this member AID (repeatable)")
    return p.parse_args()


def state_path(hby):
    base = os.path.join(os.path.dirname(os.path.dirname(hby.db.path)), "sync")
    return os.path.join(base, f"{hby.name}.json")


def load_state(path):
    try:
        with open(path) as f:
            return {k: set(v) for k, v in json.load(f).items()}
    except FileNotFoundError:
        return {}


def save_state(path, state):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump({k: sorted(v) for k, v in state.items()}, f, indent=1)
    os.replace(tmp, path)


def other_members(ghab):
    mine = ghab.mhab.pre
    members = []
    for pre in list(ghab.db.signingMembers(pre=ghab.pre) or []) + list(ghab.db.rotationMembers(pre=ghab.pre) or []):
        if pre != mine and pre not in members:
            members.append(pre)
    return members


def has_tel(reger, regk):
    try:
        reger.tevers[regk]  # lazy table: only item lookup loads a registry
        return True
    except KeyError:
        return False


def latest_registry(reger, group):
    """Registry of the most recently issued group credential with a TEL issuance here, or None."""
    best = None
    for said in group_credentials(reger, group):
        creder = reger.creds.get(keys=(said,))
        if creder is None or reger.getTel(snKey(pre=said, sn=0)) is None:
            continue
        dt = creder.attrib.get("dt", "") if isinstance(creder.attrib, dict) else ""
        if best is None or dt > best[0]:
            best = (dt, creder.regi)
    return best[1] if best else None


def saved_group_credentials(reger, group):
    return {s.qb64 for s in reger.issus.get(keys=group)}


def chunks(items):
    batch, size = [], 0
    for item in items:
        if batch and size + len(item[2]) > CHUNK:
            yield batch
            batch, size = [], 0
        batch.append(item)
        size += len(item[2])
    if batch:
        yield batch


def deliver(hby, mhab, recp, batch):
    """Send one batch to one of recp's witnesses; returns (ok, detail)."""
    postman = forwarding.StreamPoster(hby=hby, hab=mhab, recp=recp, topic="credential")
    try:
        for _, kind, raw in batch:
            serder = serdering.SerderACDC(raw=raw) if kind == "acdc" else serdering.SerderKERI(raw=raw)
            postman.send(serder=serder, attachment=raw[serder.size:])
    except kering.ValidationError as ex:
        return False, f"no witness endpoint known ({ex}); re-resolve their OOBI"
    messengers = postman.deliver()
    if not messengers:
        return False, "nothing sent (no endpoint)"
    doist = doing.Doist(limit=SEND_TIMEOUT, tock=0.03125, real=True)
    doist.do(doers=list(messengers))
    for m in messengers:
        status = getattr(getattr(m, "rep", None), "status", None)
        if status is None:
            return False, f"no response from witness {m.wit} within {SEND_TIMEOUT:.0f}s"
        if not 200 <= status < 300:
            return False, f"witness {m.wit} answered HTTP {status}"
    return True, f"via witness {messengers[0].wit}"


class Signers:
    """Which members signed the group KEL events anchoring a credential's TEL events.

    A TEL event (iss, rev) is anchored by a seal in a group interaction event;
    that event's indexed signatures are by the keys of the group's establishment
    event in force at the time, and each of those keys belongs to one member's
    KEL. Looked up historically, so issuances from before a rotation map to
    whoever the members were then.
    """

    def __init__(self, hby, reger, ghab):
        self.hby = hby
        self.reger = reger
        self.group = ghab.pre
        self.owner = {}  # member signing key qb64 -> member AID
        for pre in other_members(ghab) + [ghab.mhab.pre]:
            for msg in hby.db.clonePreIter(pre=pre):
                serder = serdering.SerderKERI(raw=bytes(msg))
                for key in serder.ked.get("k", []):
                    self.owner[key] = pre
        self.est = []  # (sn, [keys]) of the group's establishment events, ascending
        for msg in hby.db.clonePreIter(pre=self.group):
            serder = serdering.SerderKERI(raw=bytes(msg))
            if "k" in serder.ked:
                self.est.append((serder.sn, serder.ked["k"]))

    def of_event(self, sn, said):
        keys = next((k for esn, k in reversed(self.est) if esn <= sn), [])
        sigs = self.hby.db.getSigs(dgKey(self.group, said)) or []
        members = set()
        for raw in sigs:
            siger = coring.Siger(qb64b=bytes(raw))
            if siger.index < len(keys) and keys[siger.index] in self.owner:
                members.add(self.owner[keys[siger.index]])
        return members

    def of_credential(self, said):
        """Members that signed EVERY TEL event of the credential (issuance, and revocation if any)."""
        common = None
        for sn in range(2):
            dig = self.reger.getTel(snKey(pre=said, sn=sn))
            if dig is None:
                break
            sealet = self.reger.getAnc(dgKey(said, bytes(dig)))
            if sealet is None:
                return set()
            sealet = bytearray(sealet)
            seqner = coring.Seqner(qb64b=sealet, strip=True)
            saider = coring.Saider(qb64b=sealet, strip=True)
            members = self.of_event(seqner.sn, saider.qb64)
            common = members if common is None else common & members
        return common or set()


def push(hby, rgy, ghab, args):
    reger = rgy.reger
    saids, skipped = [], []
    for said in group_credentials(reger, ghab.pre):
        if reger.getTel(snKey(pre=said, sn=0)) is None:
            skipped.append(said)  # create never completed here: nothing a member could verify or revoke
        else:
            saids.append(said)
    if skipped:
        print(f"  not sending {len(skipped)} credential(s) with no TEL issuance here: {', '.join(skipped)}")
    signers = Signers(hby, reger, ghab)
    signed = {said: signers.of_credential(said) for said in saids}

    def exporter_for(recp):
        """Everything recp needs for the credentials it did not sign (all of them with --full)."""
        ex = Exporter(hby, reger)
        ex.kel(ghab.pre)
        for said in saids:
            if args.full or recp not in signed[said]:
                ex.cred(said)
        return ex

    org = connecting.Organizer(hby=hby)
    path = state_path(hby)
    state = load_state(path)
    total_ok = True
    for recp in (args.to or other_members(ghab)):
        label = f"  {alias_of(hby, org, recp) or 'member'} ({recp})"
        sent = state.setdefault(recp, set())
        ex = exporter_for(recp)
        for w in ex.warnings:
            print(f"  warning: {w}")
        own = 0 if args.full else sum(1 for said in saids if recp in signed[said])
        note = f" (skipped {own} credential(s) it signed)" if own else ""
        todo = list(ex.items) if args.full else [item for item in ex.items if item[0] not in sent]
        if not any(kind in ("acdc", "tel") for _, kind, _ in todo):
            # KEL events alone: a member already follows the group KEL
            print(f"{label}: {'up to date' if sent or own else 'nothing to send (no group credentials held here)'}{note}")
            continue
        nbytes = sum(len(i[2]) for i in todo)
        ncreds = sum(1 for i in todo if i[1] == "acdc")
        if args.dry_run:
            print(f"{label}: would send {len(todo)} message(s), {ncreds} credential(s), {nbytes} bytes{note}")
            continue
        done = 0
        for batch in chunks(todo):
            ok, detail = deliver(hby, ghab.mhab, recp, batch)
            if not ok:
                total_ok = False
                print(f"{label}: sent {done} of {len(todo)} message(s), then failed: {detail}")
                break
            sent.update(key for key, _, _ in batch)
            done += len(batch)
            save_state(path, state)  # after every batch, so a failure part way only resends the rest
        else:
            print(f"{label}: sent {len(todo)} message(s), {ncreds} credential(s), {nbytes} bytes{note}")
    return total_ok


def main():
    args = parse_args()
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        ghab = hby.habByName(args.alias)
        if ghab is None or not isinstance(ghab, GroupHab):
            print(f"group alias {args.alias!r} not found in keystore {hby.name!r}", file=sys.stderr)
            return 2
        print(f"Group: {args.alias} ({ghab.pre}), member {ghab.mhab.name} ({ghab.mhab.pre})")

        # 1. pull
        rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
        before = saved_group_credentials(rgy.reger, ghab.pre)
        if not args.no_pull:
            rgy.close()  # poll opens its own Regery; the same LMDB must not be open twice in one process
            print()
            print("1. pull")
            poll(hby, args.poll)
            rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
            new = saved_group_credentials(rgy.reger, ghab.pre) - before
            print(f"  {len(new)} new group credential(s) saved here" + (": " + ", ".join(sorted(new)) if new else ""))

        # 2. adopt
        print()
        print("2. registry")
        rc_adopt = 0
        regks = [r for r in group_registries(rgy.reger, ghab.pre) if has_tel(rgy.reger, r)]
        if not regks and rgy.registryByName(args.registry_name) is None:
            print(f"  {args.registry_name!r} not registered, and no group credential has arrived yet to "
                  f"name the registry. Another member must run sync.sh (push), then run sync.sh again here.")
            rc_adopt = 1
        for regk in regks:  # normally one; a group with an older registry too gets both
            names = registered_names(rgy.reger)
            if regk in names:
                print(f"  {names[regk]!r} registered: {regk}")
            elif ensure_registered(rgy, ghab, args.alias, args.registry_name, regk) is None:
                rc_adopt = 1

        current = rgy.registryByName(args.registry_name)
        latest = latest_registry(rgy.reger, ghab.pre)
        if current is not None and latest is not None and current.regk != latest:
            print(f"  WARNING: {args.registry_name!r} is registry {current.regk}, but the group's latest credential "
                  f"was issued into {latest}. Creates from this GAR would go to a different registry than the other "
                  f"members' and their signatures would never combine. Check the registry name in ~/.gar/*.sh "
                  f"with the other GARs.")

        # 3. push
        ok = True
        if not args.no_push:
            print()
            print("3. push" + (" (dry run)" if args.dry_run else ""))
            ok = push(hby, rgy, ghab, args)

        # 4. report
        rows, counts, adopted = collect(hby, rgy, ghab, args.registry_name)
        print()
        print("4. revoke readiness")
        summary = ", ".join(f"{n} {v}" for v, n in sorted(counts.items()))
        print(f"  {len(rows)} group credential(s) known here{': ' + summary if summary else ''}")
        for r in rows:
            if r["verdict"] == "cannot revoke":
                print(f"    {r['said']}  {r['type']}  missing: {', '.join(r['missing'])}")
        print("  Credentials no member has pushed yet are not listed; run revoke-readiness.sh with a manifest "
              "for the full comparison.")
        return 0 if ok and rc_adopt == 0 else 1
    finally:
        hby.close()


if __name__ == "__main__":
    sys.exit(main())
