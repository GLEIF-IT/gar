# Catch-up playbook: bringing every GAR's keystore up to date

Use this to make sure every member of GLEIF Internal can revoke any credential the group has issued, and to
make sure the newer GARs can create credentials at all. It is for:

- **Ali**, who only holds the credentials Ali helped issue
- **the three new GARs**, who joined the group after its registry was created and hold no credentials or
  registry

**Why.** A revoke is built in each signer's own keystore, so each signer needs three things:

- the group registry, registered under `INT_GAR_REG_NAME`
- the credential's TEL issuance event
- the credential body

Any two members can revoke (5 members at ½ each), but only if both have all three. Today, for most
credentials, only Kevin and whoever co-issued them do. A GAR without the registry also can't create
credentials: create and revoke both fail with `invalid registry name`.

**How.** `./scripts/sync.sh` does all of it over the members' KERI mailboxes, the same route `kli ipex grant`
uses to deliver a credential chain to the QVI:

1. **pull**: polls this GAR's mailboxes and ingests group credentials other members pushed, with their TELs,
   LE/QVI chain and KELs
2. **adopt**: if no registry is registered under `INT_GAR_REG_NAME` (a GAR that joined later), registers the
   group's existing one
3. **push**: sends every other member the group credentials they didn't sign and haven't been sent yet. A
   member that signed a credential's issuance (and its revocation, if any) already holds it. Each GAR records
   locally what reached whom, in `~/.gar/sync/`, so later runs send only what's new, including revocations.
4. **report**: what this GAR can revoke now

Nothing is added to any KEL or TEL, and recipients verify everything they receive. Run every command from
`internal/` in your gar checkout.

---

## 0. Everyone, once: get the scripts

```bash
cd <your gar checkout>
git pull
cd internal
grep INT_GAR_REG_NAME ~/.gar/internal.sh     # should be: Internal GAR Registry
```

The scripts are Python run inside the existing `gar/keri:1.1.44` image, so you don't need to rebuild it.
Rebuild with `./scripts/prepare.sh` only if `git pull` changed `internal/Dockerfile` or `internal/patches/`.

**New GARs: if you ever ran `create-registry.sh`, say so before continuing** (see Troubleshooting).

---

## 1. The first catch-up

Kevin signs every group issuance, so Kevin's keystore holds every group credential. On the first run, Kevin
pushes first and then everyone else pulls:

| Step | Who | Command |
|---|---|---|
| 1 | Kevin | `./scripts/sync.sh` (pushes each member every credential that member didn't sign) |
| 2 | Ali and each new GAR | `./scripts/sync.sh` (pulls Kevin's push; new GARs also adopt the registry) |

On a new GAR the output should look like this:

```
1. pull
Checking mailboxes for 20s....................
  N new group credential(s) saved here: E…, E…
2. registry
registered registry E… (group GLEIF Internal AID, E…) as 'Internal GAR Registry'
  TEL sn 0, no backers
3. push
  Kevin Griffin (E…): up to date (skipped N credential(s) it signed)
  …
4. revoke readiness
  N group credential(s) known here: N can revoke
```

On Kevin's and Ali's GARs, step 2 says `'Internal GAR Registry' registered: E…`.

**If the pull is cut off** (`N new` lower than expected, or readiness lists `missing: TEL issuance`), run
`./scripts/sync.sh --poll 60`. Anything not read yet stays in the mailbox for the next run.

**Confirm nothing is missing.** The sync report only lists credentials that some member has pushed. For a full
comparison, Kevin runs `./scripts/export-group-credentials.sh` (step 5 below) and sends the `.json` manifest
to everyone. Each GAR then runs:

```bash
./scripts/revoke-readiness.sh group-credentials-<ts>.json
```

**Done when:** every GAR's readiness against Kevin's manifest shows no `cannot revoke`. A `note: not in the
manifest` should never appear, because Kevin holds every group credential. If one does, send it to Kevin.

---

## 2. Every session from now on

```bash
source ./source.sh       # prints a reminder to run sync.sh
./scripts/sync.sh
```

Run it at the start of each session, and again after an issuance or revocation session, so the members who
didn't sign get the result. Each run sends only what is new.

| Option | Use |
|---|---|
| `--dry-run` | Show what would be pushed to each member. Send nothing. |
| `--poll 60` | Poll longer (default 20 s) |
| `--no-push` / `--no-pull` | Only one direction |
| `--to <member AID>` | Push only to one member, e.g. a GAR that just joined |
| `--full` | Resend everything, including credentials the member signed, e.g. to a member who rebuilt their keystore or stopped a create before it finished |

---

## 3. Prove it with the first real revocation

Sync never signs anything in the group, so it can't test a group revoke. Use the next revocation you
actually need: Kevin plus one new GAR. Both run `./scripts/sync.sh` first, then:

```bash
./scripts/revoke-ecr-auth-credential.sh     # or revoke-oor-auth-credential.sh; both enter the SAME datetime
```

As with grants, both members must enter the identical datetime, including microseconds, or the two
revocation events differ and the signatures never combine. Afterwards, everyone's next sync carries the
revocation to the members who didn't sign.

---

## 4. Other things a new GAR needs before issuing

- **The LE.** It arrives with the first group credential that chains to it. For a brand-new LE, export and
  import it before creating auths against it (`export-credential.sh <LE SAID>`, `import-credential.sh`).
  Otherwise that GAR's `create` never finishes. That doesn't block issuance, but the GAR looks stuck.
- **The QVI as a contact** (`./scripts/resolve-oobi.sh` with the QVI's OOBI), so the grant can reach it.
- **One parameters file per credential**: `prepare-auth-credential.sh`, then the same file on every GAR (see
  "Avoiding mismatches" in `debugging-group-issuance.md`).

---

## 5. Fallback: files instead of mailboxes

Use this when a witness is down, or a member can't reach the others' witnesses. Every step is safe to repeat,
and it combines with sync.

```bash
# A GAR that holds the credentials
./scripts/export-group-credentials.sh            # data/group-credentials-<ts>.cesr and .json

# Each other GAR, with both files (send them privately; they contain names and roles)
./scripts/import-credential.sh group-credentials-<ts>.cesr group-credentials-<ts>.json
./scripts/adopt-registry.sh group-credentials-<ts>.json        # new GARs only
./scripts/revoke-readiness.sh group-credentials-<ts>.json
```

---

## Troubleshooting

| Message | Meaning and fix |
|---|---|
| `sync: … not registered, and no group credential has arrived yet to name the registry` | Nobody has pushed to this GAR yet, or the pull was cut off. Ask Kevin to run `sync.sh`, then rerun with `--poll 60`. |
| `sync: … failed: no witness endpoint known … re-resolve their OOBI` | This GAR doesn't know where that member's witnesses are. Resolve the member's OOBI (`./scripts/resolve-oobi.sh`) and sync again. Only the unsent part is retried. |
| `sync: … failed: no response from witness … / answered HTTP …` | That witness is down or refused the message. Rerun later: each run picks a random witness of the member, and only the unsent part is resent. |
| `the name 'Internal GAR Registry' is already registered here for a different registry E…` | This GAR has a different registry under that name, most likely from an earlier `create-registry.sh`. **Do not delete anything.** Send Kevin the prefix it printed. A registry the group never co-signed is unusable but harmless. The fix is to set `INT_GAR_REG_NAME` in `~/.gar/internal.sh` to a new name, for example `Internal GAR Registry 2`, then sync again. |
| `registry E… is already registered here as 'X'` | It's already adopted, under a different name. Set `INT_GAR_REG_NAME="X"` in `~/.gar/internal.sh` instead of adding a second name. |
| `registry E… was incepted by E…, not the group` | The credentials or files are from someone else's registry. Stop and tell Kevin. |
| Readiness `missing: TEL issuance` on a credential the others can revoke | The pull was cut off before that credential's TEL event arrived. Rerun with `--poll 60`. |
| `not sending N credential(s) with no TEL issuance here` | A `create` on this GAR never completed for those. They were never issued, so there is nothing to sync or revoke. |
| `alias 'GLEIF Internal AID' not found` | `INT_GAR_AID_ALIAS` in `~/.gar/internal.sh` doesn't match this GAR's local alias for the group. |

If something isn't covered here, send Kevin the full `sync.sh` output and the output of
`./scripts/revoke-readiness.sh <manifest> --all`.
