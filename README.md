
# GLEIF Authorized Representative (GAR)

This package contains documentation and Bash shell scripts needed to use the KERIpy command line tool (`kli`) to
participate as a GLEIF Authorized Representative (GAR) as a member of the GLEIF External Autonomic Identifier (AID) or
the GLEIF Internal Autonomic Identifier (AID) 

## Repository Layout
This repository contains documentation in the `./docs` directory and Bash shell scripts in the `./scripts` directory.  The 
scripts make it easy to use the KERI command line tool `kli` to perform all functions required of a GAR.  It utilizes the KERI
docker image `gleif/keri:1.1.44`, plus a few backported `kli` fixes layered on by `internal/Dockerfile` and
`external/Dockerfile`, with mounts to local directories to minimize the requirements on the local system.  

## Getting Started
The steps needed to bootstrap your system are described in [Getting Started](./docs/getting-started.md).  After following
the steps described in that document you will have a KERI datastore and keystore encrypted using a randomly generated passcode
that is automatically stored in your Mac keychain.  

From there you will be ready to join and participate in a Group Multisig AID as described in [Creating Group AID](./docs/creating-group-aid.md).

## Further Reading
The following table contains reference matertial and repository links for the vLEI schema, the KERI protocol and ACDC
credentials, all foundational concepts and technologies for GLEIF's vLEI ecosystem:

| Acronym      | Full Name of Deliverable                           | Link to Deliverable                                 | Lead Authors                     | Status / Notes                |
|--------------|----------------------------------------------------|-----------------------------------------------------|----------------------------------|-------------------------------|
| KERI         | Key Event Receipt Infrastructure (KERI)            | [ToIP KERI Spec][KERI_SPEC]                         | Samuel Smith                     | [Specification][KERI_SPEC]    |
| vLEI EGF     | vLEI Ecosystem Governance Framework                | [vLEI EGF][EGF]                                     | Karla McKenna / Drummond Reed    | Published                     | 
| vLEI Schema  | The published JSON schema for all vLEI credentials | [vLEI Schema][VLEI_SCHEMA]                          | Phil Feaihreller / Kevin Griffin | Published                     |
| SAID         | Self-Addressing Identifiers                        | [IETF SAID Draft][SAID_IETF]                        | Samuel Smith                     | [Subsumed by spec][SAID_TOIP] |
| ACDC         | Authentic Chained Data Containers                  | [ToIP ACDC Spec][ACDC_SPEC]                         | Samuel Smith                     | [Specification][ACDC_SPEC]    |
| OOBI         | Out-Of-Band-Introduction                           | [IETF OOBI Draft][OOBI_IETF]                        | Sam Smith                        | [Subsumed by spec][OOBI_TOIP] |
| CESR         | Composable Event Streaming Representation          | [IETF CESR Draft][CESR_SPEC]                        | Samuel Smith                     | [Specification][CESR_SPEC]    |
| CESR Proof   | CESR Proof Signatures                              | [IETF CESR Proof Signatures Draft][CESR_PROOF_IETF] | Phil Feairheller                 | [Subsumed by spec][CESR_SPEC] | 
| PTEL         | Public Transaction Event Logs                      | [IETF PTEL Draft][PTEL_IETF]                        | Phil Feairheller                 | [Subsumed by spec][CESR_SPEC] | 


## Utility Scripts
There are several scripts located in the `scripts` directory that are described specifically in any flow documentation
but are provided as utilities that can be helpful for GAR controllers while participanting in the vLEI ecosystem.  The
following table describes the scripts, all of which can be used any time after the steps described in [Getting Started](./docs/getting-started.md)

| Script | Purpose |
|--------|---------|
| `./scripts/status.sh` | AID status script that can be used to inspect key state of any local AID |
| `./scripts/contacts.sh` | Script to list any contacts locally resolved through OOBI exchange.  Indicates Authentication status |
| `./scripts/delegate-confirm-preflight.sh` | External only. Read-only check before approving a QVI rotation: QVI key state held locally, escrows, witness reachability, current `anchor.json` |
| `./scripts/challenge-members.sh` | Challenge several contacts (a QVI's QARs, the other GARs) one after another with your member AID and show their Authenticated state |
| `./scripts/respond-for-group.sh` | Answer a challenge that was addressed to the group AID: prints the member alias, AID and OOBI the challenger needs, then responds with your member AID |
| `./scripts/sent-exns.sh` | List the exchange messages your AIDs sent (IPEX grants and more) with the credential, its registry state, which members signed, who delivered it, and the admit if one came back; `--poll` fetches replies first |
| `./scripts/contacts-credentials.sh` | Internal only. For each contact, the credentials the Internal AID issued to it or about it (OOR/ECR Authorization issuee or person AID), their registry state, and whether the IPEX grant was sent and admitted; `--poll` fetches admits first, `--json` for jq |
| `./scripts/prepare-auth-credential.sh oor\|ecr` | Internal only. One GAR answers the OOR/ECR auth prompts once; it writes a JSON parameters file with the LE SAID, person data, the QVI's AID and one generated datetime. Share the file; every GAR then runs `create-oor-auth-credential.sh <file>` (or `create-ecr-`) and later `grant-oor-auth-credential.sh <file>` (or `grant-ecr-`) with no prompts, so all members build the same credential and the same grant SAID. The grant finds the credential SAID from the file. Run without a file, the create and grant scripts prompt as before |
| `./scripts/ungranted-credentials.sh` | Internal only. The credentials the Internal AID has created (issued into its registry) but not yet granted, i.e. the ones still waiting for a `grant-*.sh` run; `--poll` fetches first, `--json` for jq |
| `./scripts/group-issuance-debug.sh` | Internal only. When a group OOR/ECR auth issuance stalls: what this keystore holds of the lead's `/multisig/iss` message, whether `kli multisig join` has a notification to act on, group ixn signature/witness escrows, credential escrow and TEL state, the group's IPEX grant exn and which members have signed it, mailbox indexes; `--poll N` runs join's mailbox intake first; `--resave <SAID>` finishes a `kli vc create` that was stopped before witness receipts so the credential lists as created. Runbook: [Debugging a group issuance](./internal/docs/debugging-group-issuance.md) |
| `./scripts/export-credential.sh` / `import-credential.sh` | Internal only. Move a credential this keystore holds (with its issuer KEL, TELs and full chain) to another GAR's keystore as one CESR file, e.g. the LE credential an OOR/ECR authorization chains to when the other GAR never received it |
| `./scripts/mailbox-debug.sh` | What each witness holds in one of your AIDs' mailboxes per topic and your local read index. `--all` for every witness, `--alias` picks the AID (use your member alias for `/multisig`), `--from <AID>` prints full messages from one sender, `--summary` prints one line per message (type, route, sender alias, time, SAID, embedded credential or grant) instead of the first 20 bytes |
| `./scripts/notifications-list.sh` / `notifications-rem.sh` | List or remove the notifications `kli multisig join` and `kli ipex list` read |

## Challenge/response and multisig AIDs
A group multisig AID can verify a challenge but cannot answer one with the `kli` this repository runs, so all
challenge scripts sign and verify with your member AID. What to do when someone challenges the GLEIF External or
Internal AID, how to challenge a QVI, and why the limitation exists are described in
[Challenge/response and multisig AIDs](./docs/challenge-response.md).

## Abbreviations
GEDA: GLEIF External Delegated AID
GIDA: GLEIF Internal Delegated AID
QVI:  Qualified vLEI Issuer
LE:   Legal Entity
GAR:  GLEIF Authorized Representative
QAR:  Qualified vLEI Issuer Authorized Representative
LAR:  Legal Entity Authorized Representative
ECR:  Engagement Context Role Person

[ACDC_SPEC]: https://trustoverip.github.io/tswg-acdc-specification/
[KERI_SPEC]: https://trustoverip.github.io/tswg-keri-specification/
[CESR_SPEC]: https://trustoverip.github.io/tswg-cesr-specification/
[EGF]: https://github.com/GLEIF-IT/vlei-egf
[SAID_IETF]: https://github.com/WebOfTrust/ietf-said
[SAID_TOIP]: https://trustoverip.github.io/tswg-cesr-specification/#self-addressing-identifier-said
[OOBI_IETF]: https://github.com/WebOfTrust/ietf-oobi
[OOBI_TOIP]: https://trustoverip.github.io/tswg-keri-specification/#out-of-band-introduction-oobi
[CESR_PROOF_IETF]: https://github.com/WebOfTrust/ietf-cesr-proof
[PTEL_IETF]: https://github.com/WebOfTrust/ietf-ptel
[VLEI_SCHEMA]: https://github.com/WebOfTrust/vLEI