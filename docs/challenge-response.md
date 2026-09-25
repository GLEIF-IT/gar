# Challenge/response and multisig AIDs

The vLEI EGF requires participants to authenticate each other by signing a 12-word challenge. The scripts in this
repository do this with `kli challenge verify --generate` (the challenger) and `kli challenge respond` (the
responder), see [Creating Group AID](./creating-group-aid.md#send-and-receive-challenge-messages).

Both scripts sign and verify with your **member** AID (`EXT_GAR_ALIAS` / `INT_GAR_ALIAS`), never with the group
alias, and that is deliberate: with the `kli` this repository runs (keripy 1.1.44 in `gar/keri:1.1.44`) a group
multisig AID can **verify** a challenge but **cannot answer** one. This page says what to do in each direction and
why the limitation exists.

## A challenge sent to the GLEIF External or Internal AID

Someone (a QAR, another GAR) wants proof that the people behind the group AID control it. The group cannot sign the
response, so each member answers with their own AID:

1. The challenger resolves the OOBI of each **member** AID. `./scripts/generate-oobi.sh` prints OOBIs for every AID
   in your keystore; give them the member entry, not the group entry. The challenger resolves it with an alias for
   you as a person.
2. The challenger generates words for each member separately (their own tooling, or `challenge-members.sh` below if
   they use this repository) with the **member alias** as signer, and sends each member their words privately.
3. Each member runs `./scripts/respond-for-group.sh`. It prints your member alias, AID and OOBI to hand to the
   challenger, then asks for the words and the challenger's contact alias and sends the signed response from your
   member AID. `./scripts/respond-to-challenge.sh` does the same without the explanation.
4. The challenger's verify waits up to 300 seconds, so respond while they are waiting.

What this proves: control of the member keys that make up the group AID's key state, one member at a time. It is not
a group signature over the words. The challenger also only ever sees "authenticated" against the member AIDs; the
group AID never becomes an authenticated contact in their keystore.

## Challenging a QVI (or the other GARs)

The same limitation applies on the other side: a QVI's group AID cannot answer either, so a GAR challenges each QAR's
individual AID.

1. Resolve each QAR's individual OOBI with `./scripts/resolve-oobi.sh` and give each an alias.
2. Run `./scripts/challenge-members.sh <alias> [<alias> ...]`. For each alias it prints 12 words, which you send to
   that QAR only over a private channel, and waits up to 300 seconds for the signed response. It then lists the
   Authenticated state of those contacts. `./scripts/generate-challenge.sh` does one alias at a time.
3. `./scripts/contacts.sh` shows `Authenticated: True` for each QAR who responded. The QVI group AID will never show
   as authenticated, and that is expected.

The authenticated state is recorded only in the keystore of the GAR who ran the challenge. Every GAR who needs it
runs the challenge themselves; there is no group-level record.

If verify ends with `No response found` although the QAR says they sent it, `./scripts/exn-probe.sh` runs the
mailbox through the same parser and handlers `kli challenge verify` uses and reports why the message was dropped.

## Why the group AID cannot respond

Verified against the `kli` in `gar/keri:1.1.44` (paths under `/keripy/src/keri/`):

1. **Verifying as a group works.** `kli challenge verify` starts a `MailboxDirector` on the `/challenge` topic
   (`app/cli/commands/challenge/verify.py:85`); it polls every accepted hab's mailboxes, group habs included, and
   signs the mailbox query with the member hab (`app/indirecting.py:590-593`, `:786-787`). A valid response is
   recorded in `db.reps` (`app/challenging.py:57`) and, when the words match, in `db.chas` (`verify.py:133`). Both
   tables live in the verifier's own keystore, so "authenticated" is per member, not a group decision. The
   `--alias` passed to verify is otherwise unused.
2. **Responding as a group does not work.** `kli challenge respond` builds the exn with the group AID as sender and
   calls `hab.endorse` (`challenge/respond.py:109-115`). For a `GroupHab` that ends in `GroupHab.sign`
   (`app/habbing.py:2770-2853`), which produces one indexed signature from this member's key, sealed against the
   group's last establishment event, and sends it from the member hab. On the verifier, `Exchanger.processEvent`
   verifies against the group key state, fails `tholder.satisfy` unless the group is 1-of-N, escrows the exn and
   raises `MissingSignatureError` (`peer/exchanging.py:89-98`). The handler never runs and verify times out with
   `No response found`.
3. **Other members cannot complete it by also responding.** `exchanging.exchange` stamps `dt` with the current time
   when none is given (`peer/exchanging.py:312`) and `kli challenge respond` has no date flag (`respond.py:18-27`), so
   each member's exn has a different SAID and their partial signatures never meet. `RespondDoer` has no local
   `Exchanger` (`respond.py:82`), so nothing aggregates on the sender side either. In 1.1.44 the verifier's escrow of
   partially signed exns never expires (there is no `TimeoutPSE`; `ExchangeMessageTimeWindow` at
   `exchanging.py:17` is unused), whereas 1.2.x drops it after 20 seconds; either way the pieces do not combine.
   Also, `--words @file` crashes in this version (`respond.py:44` reads a field that does not exist).
4. **Group-signed exns exist, but only for IPEX.** `grouping.multisigExn` (`app/grouping.py:481-504`) wraps an exn in
   a `/multisig/exn` message to the other members; `kli ipex grant` uses it, waits for the group signatures and lets
   the lead member send the result (`ipex/grant.py:126-156`); `kli ipex join` only accepts embedded routes starting
   with `/ipex` (`ipex/join.py:121`). Nothing does this for `/challenge/response`, and `kli multisig` has no generic
   co-signing command.

`ChallengeHandler` itself records the exn's sender prefix (`challenging.py:43-57`), so a properly group-signed
response would be accepted; the blocker is producing one.

## What a proper fix in keripy would look like

- A `--time` flag on `kli challenge respond` so every member builds the identical exn (same `dt`, same SAID).
- A local `Exchanger` in `RespondDoer` so the members' partial signatures can be collected on the sender side.
- A `/multisig/exn` round trip for `/challenge/response` like IPEX grant/join: the initiating member sends the
  embedded exn to the other members on the `multisig` topic, a join-style handler accepts the `/challenge` route,
  and only the lead member sends `exchanging.serializeMessage` output to the challenger.
- On the verifier, a bounded escrow for partially signed exns: add a timeout in 1.1.x (today it never expires) and
  raise `Exchanger.TimeoutPSE` well above 20 seconds in 1.2.x, so late partial signatures still combine.

Until then, challenge and answer with member AIDs and document that this is what was proven.
