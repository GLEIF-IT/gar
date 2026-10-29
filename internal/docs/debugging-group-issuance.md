# Debugging a group credential issuance the other GAR never sees

Use this when the lead GAR has run `issue-oor-auth-credential.sh` (or any `kli vc create` for the group AID) and
the other GAR's `multisig-join.sh` shows nothing. Everything below runs from `internal/` on the GAR that is NOT
seeing the credential unless a step says "on the lead". Steps 1 to 3 are read-only.

## How it is supposed to work

1. Lead: `kli vc create` builds the credential, its TEL issuance event and a partially signed group interaction
   event, sends one `/multisig/iss` exchange message to **one random witness of each other member**, then waits.
2. Other GAR: `kli multisig join` polls its member AID's mailboxes on the `/multisig` topic. The message is stored,
   a **notification** is written, join shows it and asks to approve. Approval signs the same event and sends it back.
3. Lead: collects the signature, the event is witnessed, the TEL event is anchored, the credential is saved. Only
   then `kli ipex grant` sends it to the QVI.

The other GAR therefore needs three things in order: the message in a witness mailbox, the message pulled into its
keystore with a notification, and a join that actually waits for and shows that notification. In keripy 1.1.44
each of those can fail silently. All of them depend on keystore state that builds up over time, so a GAR that
joined fine last week can see nothing this week.

## Step 1: take a snapshot

```bash
./scripts/group-issuance-debug.sh
```

Read the sections in this order:

| Section | What you want to see | If not |
|---|---|---|
| members | your member AID with `signing index` set and end roles (witness) listed | the lead cannot deliver to you; see step 5 |
| notifications | none, or only `/multisig/*` routes | `!! N non-multisig notification(s)`: join will exit at once; see step 2 |
| multisig exns held | a `/multisig/iss` for the new credential with `notification: present` | missing entirely: see step 3; present with no notification: see step 4 |
| group KEL partially signed | the new interaction event with the lead's signature | nothing: the message has not been processed yet |
| credential | `saved/indexed True`, `issued by group True` | body held and TEL issued but not saved: create was stopped before receipts; see step 4b. Edge node `saved here False`: admit the LE credential first |
| mailbox indexes | one row per witness of your member AID | used in step 3 |

The script never changes anything unless you give it `--poll`.

## Step 2: stale notifications (join exits immediately)

`kli multisig join` waits only while the notification table is **empty**, then makes one pass and exits. Any IPEX
grant or admit notification left behind (e.g. the QVI's admit for last week's credential) ends that wait before the
mailbox has been polled. join prints "Waiting for group multisig events..." and returns in under a second.

Either remove the old notes:

```bash
./scripts/notifications-list.sh            # (blocks if the table is empty: ctrl-c)
./scripts/notifications-rem.sh --rid <rid>  # one per stale note, or --all
```

or skip the wait entirely by pulling the mailbox first (step 3) so the issuance notification already exists when
join starts. Do not `--all` if a `/multisig/*` note is listed: that is the one you want.

A `/multisig/*` note flagged `!! no 'd' attribute` was written by an older keripy and is worse than stale: join
reads `attrs["d"]` from it and crashes with a `KeyError` before it reaches any later notification. Remove it with
the `notifications-rem.sh --rid` line the script prints, then continue.

## Step 3: the message never arrived in this keystore

```bash
./scripts/group-issuance-debug.sh --poll 15
```

This runs the same `/multisig` intake join uses and reports what arrived. If a `/multisig/iss` appears, go to
step 6. If nothing arrives, find out whether it is sitting at a witness:

```bash
./scripts/mailbox-debug.sh --all --alias "<your member alias>"
```

Compare each witness's `/multisig` messages against the `mailbox indexes` printed in step 1. The poller fetches
from the stored index plus one, so:

- **Message index above the stored index**: it has not been pulled. Re-run `--poll 30`; if it still does not
  come, that witness is not answering mailbox queries. Check connectivity to it.
- **Message index at or below the stored index, but not in "multisig exns held"**: it was pulled and dropped.
  `kli multisig continue`, `kli kevers` and `kli vc registry status` poll `/multisig` with no exchange handler;
  the index advances on receipt and the message is discarded. Rewind the index and join again:

  ```bash
  ./scripts/mailbox-update.sh -a "<your member alias>" -w <witness AID> -t /multisig -i <message index - 1>
  ./scripts/multisig-join.sh
  ```

- **No `/multisig/iss` at any witness**: the lead never delivered it. Go to step 5.

## Step 4: message held, no notification (re-sent issuance)

The Multiplexor writes a notification only for the **first** message about a given embedded event. For a later
one with the same SAIDs it decides "we already approved this" and stores it silently. The debug script flags this
as more than one exn for the embedded event with no notification. It happens when the lead re-runs the issuance
with the same data: `issue-oor-auth-credential.sh` hardcodes `--time 2024-03-18T14:52:55+00:00`, so a re-run for
the same person produces the identical credential SAID.

Fix on the lead: re-create with a different `--time`, or change the data. Then start again from step 1 here.

## Step 4b: created and TEL issued here, but never saved (create stopped early)

The credential section shows `body held True`, `TEL state issued ...`, `missing-sig escrow YES`, but
`saved/indexed False` and `issued by group False`. This is what a `kli vc create` that was stopped with ctrl-c
before all witness receipts arrived leaves behind. Only the member whose key is at index 0 submits the group
event to the witnesses; everyone else's create just asks the witnesses for receipts until all of them are in,
which can take a while when a witness is slow. Stopping it leaves the credential in the verifier's
missing-registry escrow. Later commands do pick up the receipts and accept the TEL event (hence `issued`), but
that escrow is only re-processed inside create/join/ipex loops and is discarded as stale after an hour, so the
save that writes the issuer index never runs. `ungranted-credentials.sh` and `kli vc list --issued` read that
index, so the credential is invisible here even though it is fully issued.

The lead is unaffected: the lead's copy saved and the grant goes from the lead. To make this keystore's copy
visible without re-issuing:

```bash
./scripts/group-issuance-debug.sh --resave <credential SAID>
```

It re-runs the verifier save on the held credential and reports. If it says the TEL state is still missing,
receipts have not been collected here yet: run `./scripts/witness-catchup.sh` or let a `kli vc create` /
`kli multisig join` run for a minute, then try again. If the `edge 'le'` line shows `saved here False`, the
save cannot chain to the Legal Entity credential; admit it (`admit-le-credential.sh`) first.

To avoid it next time: let `kli vc create` run until it prints `<SAID> has been created.`

## Step 5: on the lead

```bash
./scripts/group-issuance-debug.sh --said <credential SAID>
```

- `members`: the other member must show end roles. If `endsFor` is empty for them, the lead has no witness or
  mailbox endpoint to send to. Re-resolve their OOBI (`./scripts/resolve-oobi.sh` or `kli oobi resolve`) and
  re-run the issuance.
- `Counselor escrows` / `credential`: a credential in `gpse` or the missing-sig escrow is the lead waiting on the
  other signature. That is normal while the other GAR has not approved. `kli vc create` must be running (or be
  started again) when the other side approves, or the returned signature sits in the lead's mailbox until the next
  `/multisig` poll.
- Check witness delivery: `./scripts/mailbox-debug.sh --all --alias "<other member alias>"` only works from the
  other GAR's keystore, so if the other side sees nothing at any witness and end roles look right, re-run the
  issuance and watch the lead's output for the forwarding error.

## Step 6: join

```bash
./scripts/multisig-join.sh
```

Approve the `/multisig/iss` when prompted. If join shows an old event first, answer `n` and let it delete it.
After approving, the lead's `kli vc create` should complete within a minute; it then runs `kli ipex grant`.
Confirm from either side with `./scripts/contacts-credentials.sh --contact pr-as-qvi-euro --poll 10`, which
lists the new credential under the QVI and whether an admit has come back.

## What to send if it is still stuck

The output of step 1 from both GARs, the `mailbox-debug.sh --all` output from the other GAR, and the lead's
terminal output from `kli vc create`. Those three show where the message stopped.
