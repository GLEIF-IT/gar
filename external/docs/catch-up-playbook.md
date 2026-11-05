# Catch-up playbook: QVI credentials on every External GAR

Use this so every member of GLEIF External can take part in revoking any QVI credential the group has
issued, and so GARs that joined the group later can issue at all. It works the same way as
`internal/docs/catch-up-playbook.md`.

**Why.** A revoke (`revoke-qvi-credential.sh`) is built in each signer's own keystore, so each signer needs
three things:

- the group registry, registered under `EXT_GAR_REG_NAME`
- the credential's TEL issuance event
- the credential body

A GAR only holds the QVI credentials it helped issue. A GAR that joined after the registry was created holds
none and has no registry, so its create and revoke fail with `invalid registry name`.

**How.** `./scripts/sync.sh` runs four steps over the members' KERI mailboxes:

1. **pull**: ingests QVI credentials other members pushed, with their TELs and the key event logs needed to
   verify them (GLEIF External and its delegator)
2. **adopt**: on a GAR that joined later, registers the group's existing registry under `EXT_GAR_REG_NAME`.
   Never run `create-registry.sh` for this: a new registry can't revoke the group's credentials.
3. **push**: sends every other member the QVI credentials they didn't sign and haven't been sent yet. What
   reached whom is recorded in `~/.gar/sync/`.
4. **report**: what this GAR can revoke now

Nothing is added to any KEL or TEL, and recipients verify everything they receive. Run every command from
`external/` in your gar checkout. `EXT_GAR_REG_NAME` is a local name and may differ between GARs. Whatever it
is, the create and revoke scripts on that GAR use it.

---

## 1. The first catch-up

```bash
git pull
cd external
./scripts/sync.sh --no-pull --dry-run     # see what would go to each member; sends nothing
```

Kevin signs every QVI issuance, so Kevin's keystore holds every QVI credential the group has issued. On the
first run, Kevin pushes first and then everyone else pulls:

| Step | Who | Command |
|---|---|---|
| 1 | Kevin | `./scripts/sync.sh` (pushes each member every QVI credential that member didn't sign) |
| 2 | Every other External GAR | `./scripts/sync.sh` (pulls Kevin's push; new GARs also adopt the registry) |

On a new GAR the output should end with:

```
2. registry
registered registry E… (group GLEIF External AID, E…) as 'External GAR Registry'
…
4. revoke readiness
  N group credential(s) known here: N can revoke
```

If the pull is cut off (fewer credentials than expected, or `missing: TEL issuance`), rerun with
`./scripts/sync.sh --poll 60`.

**Confirm nothing is missing.** The sync report only lists credentials some member has pushed. For the full
comparison, Kevin runs `./scripts/export-group-credentials.sh` and shares the `.json` manifest. Each GAR then
runs `./scripts/revoke-readiness.sh <manifest>`. **Done when** no GAR shows `cannot revoke`. A `note: not in
the manifest` should never appear, because Kevin holds every QVI credential. If one does, send it to Kevin.

---

## 2. Every session from now on

```bash
source ./source.sh       # prints a reminder to run sync.sh
./scripts/sync.sh
```

Run it again after any issuance or revocation, so the members who didn't sign get the result. The options are
the same as on the internal side: `--dry-run`, `--poll 60`, `--no-push` / `--no-pull`, `--to <member AID>` and
`--full` (resend everything, including credentials the member signed).

---

## 3. Fallback: files instead of mailboxes

```bash
./scripts/export-group-credentials.sh                                          # Kevin
./scripts/import-credential.sh group-credentials-<ts>.cesr group-credentials-<ts>.json   # each other GAR
./scripts/adopt-registry.sh group-credentials-<ts>.json                        # new GARs only
./scripts/revoke-readiness.sh group-credentials-<ts>.json
```

Send the files privately. The error messages and fixes are the same as in the troubleshooting table of
`internal/docs/catch-up-playbook.md`, with `EXT_GAR_*` in place of `INT_GAR_*`.
