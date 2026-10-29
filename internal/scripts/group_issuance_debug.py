#!/usr/bin/env python3
"""
Diagnose a group credential issuance that is stuck between the GARs.

How a group issuance travels (keripy 1.1.44):

  lead GAR   `kli vc create --alias <group>`  creates the credential, its TEL
             iss event and a partially signed group ixn anchoring it, then sends
             ONE /multisig/iss exn to each other member (to one of that member's
             witnesses, mailbox topic "<member>/multisig") and waits until the
             group ixn is fully signed and witnessed.
  other GAR  `kli multisig join`  polls its mailboxes on /multisig, the Exchanger
             hands the exn to the Multiplexor, which records it (meids/maids) and
             writes a NOTIFICATION; join then shows the notification, asks to
             approve, signs the same ixn and sends its own /multisig/iss back.

Places it can stall, and what this script reports for each:
  1. The lead cannot deliver: it needs end roles (witnesses or mailbox) for the
     other member.                           -> "members" section (endsFor)
  2. The message sits at a witness unread.   -> "mailbox indexes" (and --poll)
  2b. The message was pulled and DROPPED. `kli multisig continue`, `kli kevers`
     and `kli vc registry status` poll /multisig with no Exchanger: the poller
     advances the witness index on receipt, the parser then has nothing to hand
     the exn to and discards it. Nothing in this keystore records it, and join
     polls from the advanced index so it never sees it. The exn is still in the
     witness mailbox below the stored index.  -> "mailbox indexes" + mailbox-debug
  3. The exn arrived but produced no notification. The Multiplexor only notifies
     on the FIRST exn for a given embedded event; a re-sent or re-created
     issuance with the same SAIDs is parsed silently instead (it mistakes any
     known member for "us" when deciding we already approved).
                                             -> "multisig exns" section
  4. `kli multisig join` exits at once: it waits only while the notification
     table is EMPTY, then makes one pass. Stale notes (IPEX grants/admits that
     `kli ipex list` leaves behind) end that wait before the /multisig/iss has
     been polled.                            -> "notifications" section
  5. Approved but never completes: the group ixn is waiting for signatures or
     witness receipts.                       -> "group escrows" / "KEL" sections
  6. Credential held but not finished: still in the missing-signature escrow.
                                             -> "credential" section

Read-only by default. --poll N runs the same mailbox intake `kli multisig join`
uses (topic /multisig, grouping handlers) for N seconds and reports what arrived;
that DOES store exns and create notifications, which is what a following
`kli multisig join` needs.

Usage (normally via group-issuance-debug.sh):
  group_issuance_debug.py --name <keystore> --passcode <bran> --alias <group alias>
                          [--said <credential SAID>] [--poll SECONDS]
"""
import argparse
import sys

from hio.base import doing

from keri import kering
from keri.app import connecting, grouping, indirecting, notifying
from keri.app.cli.common import existing
from keri.core import coring, serdering
from keri.db import dbing
from keri.help import helping
from keri.peer import exchanging
from keri.vdr import credentialing, verifying

from sent_exns import alias_of, credential_state, iter_exns


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", "-n", required=True)
    p.add_argument("--base", "-b", default="")
    p.add_argument("--passcode", "-p", dest="bran", default=None)
    p.add_argument("--alias", "-a", required=True, help="alias of the group AID")
    p.add_argument("--said", "-s", default=None, help="only this credential SAID")
    p.add_argument("--poll", type=float, default=0, metavar="SECONDS",
                   help="first run the /multisig mailbox intake for this long (stores what arrives)")
    p.add_argument("--resave", metavar="SAID", default=None,
                   help="re-run the verifier save on a credential this keystore created but never saved/indexed "
                        "(a `kli vc create` stopped before witness receipts arrived); then report on it")
    return p.parse_args()


def who(hby, org, pre):
    a = alias_of(hby, org, pre)
    return f"{a} ({pre})" if a else pre


def h(title):
    print()
    print(f"== {title}")


def main():
    args = parse_args()
    hby = existing.setupHby(name=args.name, base=args.base, bran=args.bran)
    try:
        ghab = hby.habByName(args.alias)
        if ghab is None:
            print(f"alias {args.alias!r} not found in keystore {hby.name!r}", file=sys.stderr)
            return 2
        if not hasattr(ghab, "mhab"):
            print(f"alias {args.alias!r} is not a group AID", file=sys.stderr)
            return 2
        if args.poll:
            poll(hby, args.poll)
        # One Regery for the whole run: opening the registry LMDB twice in one process is unsafe
        # (MDB_BAD_RSLOT: invalid reuse of reader locktable slot).
        rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
        if args.resave:
            rc = resave(hby, rgy, ghab, args.resave)
            report(hby, rgy, ghab, args.resave)
            return rc
        report(hby, rgy, ghab, args.said)
        return 0
    finally:
        hby.close()


def poll(hby, seconds):
    """The intake half of `kli multisig join`: poll /multisig, route exns through the Multiplexor."""
    notifier = notifying.Notifier(hby=hby)
    exc = exchanging.Exchanger(hby=hby, handlers=[])
    grouping.loadHandlers(exc=exc, mux=grouping.Multiplexor(hby=hby, notifier=notifier))
    mbx = indirecting.MailboxDirector(hby=hby, topics=["/multisig"], exc=exc)
    before_exns = {said for said, _ in iter_exns(hby.db)}
    before_notes = notifier.noter.notes.cntAll()
    sys.stdout.write(f"Polling /multisig mailboxes for {seconds:.0f}s")
    sys.stdout.flush()

    class Tick(doing.Doer):
        def recur(self, tyme):
            sys.stdout.write(".")
            sys.stdout.flush()
            return False

    doing.Doist(limit=seconds, tock=1.0, real=True).do(doers=[mbx, Tick()])
    print()
    new = [said for said, _ in iter_exns(hby.db) if said not in before_exns]
    print(f"pollers: {len(mbx.pollers)}   new exns stored: {len(new)}   "
          f"notifications: {before_notes} -> {notifier.noter.notes.cntAll()}")


def resave(hby, rgy, ghab, said):
    """Finish what a stopped `kli vc create` left undone: run the verifier's save for a credential whose body
    and anchor are held here but which never reached the saved/issus indexes. Only the verifier escrows
    (which nothing outside create/join re-runs, and which expire after an hour) stood between the two.
    Writes exactly what Verifier.saveCredential and Credentialer.processCredentialMissingSigEscrow would."""
    reger = rgy.reger
    h(f"resave {said}")
    creder = reger.creds.get(keys=(said,))
    if creder is None:
        print("  credential body is not held in this keystore; nothing to save")
        return 1
    if creder.issuer != ghab.pre:
        print(f"  credential issuer {creder.issuer} is not the group AID {ghab.pre}; refusing")
        return 1
    if reger.saved.get(keys=said) is not None:
        print("  already saved/indexed here; nothing to do")
        return 0
    anc = reger.cancs.get(keys=(said,))
    if anc is None:
        print("  no anchor record (cancs) for this credential; it was never processed here")
        return 1
    prefixer, seqner, saider = anc
    state = credential_state(reger, said)
    print(f"  TEL state now: {state}")
    vry = verifying.Verifier(hby=hby, reger=reger)
    try:
        vry.processCredential(creder=creder, prefixer=prefixer, seqner=seqner, saider=saider)
    except kering.MissingRegistryError as ex:
        print(f"  not saved: registry/TEL state still missing here ({ex}). Run the group escrows first")
        print("  (e.g. witness-catchup.sh, or re-run the create and let it finish) and try again.")
        return 1
    except kering.MissingChainError as ex:
        print(f"  not saved: an edge node credential is not saved here ({ex}); admit it first")
        return 1
    except kering.MissingSchemaError as ex:
        print(f"  not saved: schema not cached here ({ex})")
        return 1
    except Exception as ex:
        print(f"  not saved: {type(ex).__name__}: {ex}")
        return 1
    if reger.saved.get(keys=said) is None:
        print("  verifier returned but the credential is still not saved; aborting")
        return 1
    for (s_, snq), _ in list(reger.cmse.getItemIter()):
        if s_ == said:
            reger.cmse.rem(keys=(s_, snq))
    reger.ccrd.put(keys=(said,), val=creder)
    print("  saved and indexed: it will now appear in ungranted-credentials.sh and `kli vc list --issued`")
    return 0


def report(hby, rgy, ghab, only_said):
    db = hby.db
    org = connecting.Organizer(hby=hby)
    reger = rgy.reger
    mhab = ghab.mhab
    kever = ghab.kever

    # ---- group and members -------------------------------------------------
    h("group")
    print(f"group   {ghab.name} ({ghab.pre})")
    print(f"me      {who(hby, org, mhab.pre)}")
    print(f"KEL     sn {kever.sn}  last {kever.serder.ilk} {kever.serder.said}  threshold {kever.tholder.sith!r}")
    print(f"members {len(ghab.smids)}")
    keys = [v.qb64 for v in kever.verfers]
    for m in ghab.smids:
        if m == mhab.pre:
            print(f"  {who(hby, org, m)}  <- this keystore")
            continue
        try:
            mk = hby.kevers[m]
            state = f"key state sn {mk.sn}"
            idx = keys.index(mk.verfers[0].qb64) if mk.verfers[0].qb64 in keys else None
            state += f", signs at index {idx}" if idx is not None else ", CURRENT KEY NOT IN GROUP KEYS (stale member key state?)"
        except KeyError:
            state = "NO KEY STATE HELD (resolve this member's OOBI)"
        ends = mhab.endsFor(m)
        roles = ", ".join(f"{r}:{len(v)}" for r, v in ends.items()) or "NONE (lead cannot deliver /multisig exns to this member)"
        print(f"  {who(hby, org, m)}  {state}  ends {roles}")

    # ---- notifications ----------------------------------------------------
    h("notifications (what `kli multisig join` reads)")
    notifier = notifying.Notifier(hby=hby)
    notes = list(notifier.noter.notes.getItemIter())
    stale = 0
    broken = []
    for keys_, note in notes:
        a = note.attrs if isinstance(note.attrs, dict) else {}
        route = a.get("r") if isinstance(a.get("r"), str) else "?"
        said = a.get("d") if isinstance(a.get("d"), str) else None
        rid = keys_[-1] if isinstance(keys_, tuple) else keys_
        tag = ""
        if route.startswith("/multisig/"):
            if said is None:
                tag = "  !! no 'd' attribute"
                broken.append(rid)
            else:
                exn, _ = exchanging.cloneMessage(hby, said)
                tag = "  (exn body MISSING)" if exn is None else ""
        else:
            stale += 1
        print(f"  {str(note.datetime)[:19]}  {'read' if note.read else 'new '}  {route:<20}  {said}  rid {rid}{tag}")
        if said is None:
            print(f"      attrs: {a}")
    if not notes:
        print("  (none)")
    if broken:
        print(f"  !! {len(broken)} /multisig notification(s) without a 'd' attribute (not written by keripy 1.1.44's")
        print("     Multiplexor; left over from an older version). `kli multisig join` does attrs['d'] on these and")
        print("     crashes with KeyError before it reaches any later notification. Remove them first:")
        for rid in broken:
            print(f"       ./scripts/notifications-rem.sh --rid {rid}")
    if stale:
        print(f"  !! {stale} non-multisig notification(s). `kli multisig join` stops waiting as soon as the table is")
        print("     non-empty and makes a single pass, so with these present it exits before a new /multisig/iss")
        print("     is polled. Remove them (notifications-rem.sh --rid ...) or use --poll here first, then join.")

    # ---- multisig exns ----------------------------------------------------
    h("multisig exns held in this keystore")
    rows = []
    for said, serder in iter_exns(db):
        ked = serder.ked
        if not ked.get("r", "").startswith("/multisig/"):
            continue
        embeds = ked.get("e") if isinstance(ked.get("e"), dict) else {}
        acdc = embeds.get("acdc") if isinstance(embeds.get("acdc"), dict) else None
        if only_said and (acdc or {}).get("d") != only_said:
            continue
        rows.append((ked.get("dt", ""), serder, embeds, acdc))
    rows.sort(key=lambda r: r[0])
    noted = {n.attrs.get("d") for _, n in notes}
    cred_saids = []
    for dt, serder, embeds, acdc in rows:
        ked = serder.ked
        mine = ked["i"] in hby.prefixes
        print(f"  {dt[:19]}  {ked['r']:<14}  {'SENT    ' if mine else 'received'}  {serder.said}")
        print(f"      from  {who(hby, org, ked['i'])}")
        esaid = embeds.get("d")
        if acdc:
            cred_saids.append(acdc.get("d"))
            print(f"      acdc  {acdc.get('d')}  schema {acdc.get('s')}  issuee {who(hby, org, (acdc.get('a') or {}).get('i', '?'))}")
        iss = embeds.get("iss") if isinstance(embeds.get("iss"), dict) else None
        if iss:
            print(f"      iss   {iss.get('d')}  registry {iss.get('ri')}")
        anc = embeds.get("anc") if isinstance(embeds.get("anc"), dict) else embeds.get("ixn") if isinstance(embeds.get("ixn"), dict) else None
        sn = None
        if anc:
            try:
                sn = int(anc.get("s", "0"), 16)
            except ValueError:
                sn = anc.get("s")
            print(f"      anc   {anc.get('t')} sn {sn} {anc.get('d')}  (group KEL is at sn {kever.sn})")
        subs = [p.qb64 for p in db.maids.get(keys=(esaid,))] if esaid else []
        exns = [s.qb64 for s in db.meids.get(keys=(esaid,))] if esaid else []
        print(f"      embedded-event SAID {esaid}: {len(exns)} exn(s) from " +
              (", ".join(alias_of(hby, org, p) or p for p in subs) or "nobody"))
        if not mine:
            # Already acted on: the credential is indexed, the anchoring event is in the group KEL, the
            # group itself exists (icp/rot), or the embedded exn (e.g. an IPEX grant) is stored.
            handled = (acdc and reger.saved.get(keys=acdc.get("d")) is not None) \
                or (anc and isinstance(sn, int) and sn <= kever.sn) \
                or ked["r"] in ("/multisig/icp", "/multisig/rot") \
                or (ked["r"] == "/multisig/exn" and isinstance(embeds.get("exn"), dict)
                    and db.exns.get(keys=(embeds["exn"].get("d"),)) is not None)
            if serder.said in noted:
                print("      notification: present" + ("  (already handled; join will show it again)" if handled else ""))
            elif handled:
                print("      notification: none (handled earlier, join consumed it)")
            else:
                print("      notification: NONE for this exn")
                others = [p for p in subs if p not in hby.prefixes]
                if len(exns) > 1 and others:
                    print("      !! not the first exn for this embedded event: the Multiplexor parsed it silently instead of")
                    print("         notifying (it treats any member with known key state as 'already approved by us').")
                    print("         `kli multisig join` will never show it. Approve via the earlier notification if it still")
                    print("         exists, or have the lead re-create with a new --time so the SAIDs change.")
                else:
                    print("      !! notification was removed or never written; `kli multisig join` has nothing to show.")
    if not rows:
        print("  (none)" + (f" for credential {only_said}" if only_said else ""))

    # ---- KEL escrows for the group --------------------------------------------
    h("group KEL: partially signed events")
    found = False
    key = ekey = b""
    while True:
        for ekey, edig in db.getPseItemsNextIter(key=key):
            pre, sn = dbing.splitSnKey(ekey)
            pre = pre.decode() if isinstance(pre, (bytes, memoryview)) else pre
            if pre != ghab.pre:
                continue
            found = True
            dgkey = dbing.dgKey(pre, bytes(edig))
            raw = db.getEvt(dgkey)
            ilk = serdering.SerderKERI(raw=bytes(raw)).ilk if raw else "?"
            sigs = [coring.Siger(qb64b=bytes(s)) for s in db.getSigs(dgkey)]
            signed = []
            for s in sigs:
                m = next((m for m in ghab.smids if s.index < len(keys) and hby.kevers[m].verfers[0].qb64 == keys[s.index]), None)
                signed.append(alias_of(hby, org, m) or m or f"index {s.index}")
            print(f"  sn {sn}  {ilk}  {bytes(edig).decode()}  signatures {len(sigs)} of {len(ghab.smids)} (threshold {kever.tholder.sith!r}): "
                  + (", ".join(signed) or "none"))
        if ekey == key:
            break
        key = ekey
    if not found:
        print("  (none)")

    h("group escrows (Counselor)")
    any_ = False
    for label, table in (("waiting for member signatures", db.gpse), ("waiting for delegation approval", db.gdee),
                         ("waiting for witness receipts", db.gpwe)):
        for (pre,), (seqner, saider) in table.getItemIter():
            if pre != ghab.pre:
                continue
            any_ = True
            done = db.cgms.get(keys=(pre, seqner.qb64))
            print(f"  {label}: sn {seqner.sn} {saider.qb64}" + ("  (already marked complete)" if done else ""))
    if not any_:
        print("  (none)")

    # ---- credential ---------------------------------------------------------
    h("credential(s)")
    saids = [only_said] if only_said else list(dict.fromkeys(s for s in cred_saids if s))
    for (said, snq), creder in reger.cmse.getItemIter():
        if said not in saids and (not only_said):
            saids.append(said)
    if not saids:
        print("  (no credential SAID known; pass --said)")
    for said in saids:
        creder = reger.creds.get(keys=(said,))
        print(f"  {said}")
        print(f"      body held        {creder is not None}" + (f"  schema {creder.sad.get('s')}" if creder else ""))
        print(f"      saved/indexed    {reger.saved.get(keys=said) is not None}")
        pend = [snq for (s, snq) in (k for k, _ in reger.cmse.getItemIter()) if s == said]
        print(f"      missing-sig escrow {'YES (TEL iss sn ' + ', '.join(str(coring.Seqner(qb64=q).sn) for q in pend) + ')' if pend else 'no'}")
        print(f"      issued by group  {any(s.qb64 == said for s in reger.issus.get(keys=ghab.pre))}")
        print(f"      TEL state        {credential_state(reger, said)}")
        print(f"      registrar done   ctel {reger.ctel.get(keys=(said, coring.Seqner(sn=0).qb64)) is not None}"
              f"  ccrd {reger.ccrd.get(keys=(said,)) is not None}"
              f"  (ccrd is what `kli multisig join` waits for before printing 'complete')")
        # Verifier escrows: the credential sits in one of these until processCredential succeeds and
        # saveCredential writes saved/issus. Entries older than the timeout are dropped on the next pass.
        held = []
        for label, table, timeout in (("missing registry/TEL", reger.mre, 3600), ("missing chain (edge)", reger.mce, 3600),
                                      ("missing schema", reger.mse, 3600)):
            dater = table.get(keys=(said,))
            if dater is not None:
                age = (helping.nowUTC() - helping.fromIso8601(dater.dts)).total_seconds()
                held.append(f"{label} since {dater.dts[:19]} ({int(age)}s{', STALE: will be dropped' if age > timeout else ''})")
        if held:
            print("      verifier escrow  " + "; ".join(held))
        elif reger.saved.get(keys=said) is None and creder is not None:
            print("      verifier escrow  none, and not saved: the escrow timed out (1h) or join exited before the")
            print("                       verifier re-processed it. Nothing in kli re-runs this; see edges below.")
        # Edge chain: saveCredential requires every edge node to be saved here with a known TEL state.
        if creder is not None:
            edges = creder.sad.get("e") if isinstance(creder.sad.get("e"), dict) else {}
            for label, node in edges.items():
                if label in ("d", "o") or not isinstance(node, dict):
                    continue
                nsaid = node.get("n")
                ncred = reger.creds.get(keys=(nsaid,))
                nsaved = reger.saved.get(keys=nsaid) is not None
                print(f"      edge '{label}'  {nsaid}  op {node.get('o') or '(default I2I)'}")
                print(f"          saved here {nsaved}  body held {ncred is not None}  TEL state {credential_state(reger, nsaid)}")
                if ncred is not None:
                    ni = (ncred.sad.get("a") or {}).get("i")
                    print(f"          issuee {who(hby, org, ni) if ni else None}  {'== group AID' if ni == ghab.pre else '!= group AID (I2I check fails)'}")
                if not nsaved:
                    print(f"          !! not saved in this keystore: the verifier cannot chain to it, so this credential")
                    print(f"             will never be saved/indexed here. Admit the {label.upper()} credential first")
                    print(f"             (admit-le-credential.sh) and have the lead re-issue, or re-process the escrow.")

    # ---- mailbox indexes ------------------------------------------------------
    h("mailbox indexes (/multisig topic, per local AID and witness)")
    shown = False
    for (pre, wit), rec in db.tops.getItemIter():
        if pre not in hby.prefixes:
            continue
        idx = rec.topics.get("/multisig")
        if idx is None:
            continue
        shown = True
        print(f"  {who(hby, org, pre)}  @ {who(hby, org, wit)}  /multisig index {idx}")
    if not shown:
        print("  (no /multisig index yet: this keystore has never pulled a /multisig message)")
    print("  The lead's exn goes to ONE random witness of YOUR MEMBER AID. To see what each witness holds:")
    print(f"    mailbox-debug.sh --all --alias \"{mhab.name}\"")
    print("  If a /multisig/iss exn shows there at an index AT OR BELOW the one stored here, but is not listed")
    print("  in the 'multisig exns' section above, something polled /multisig without a handler and dropped it")
    print("  (kli multisig continue, kli kevers, kli vc registry status all do). Rewind and re-join:")
    print(f"    mailbox-update.sh -a \"{mhab.name}\" -w <witness AID> -t /multisig -i <that index minus 1>")
    print("    multisig-join.sh")


if __name__ == "__main__":
    sys.exit(main())
