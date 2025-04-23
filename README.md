
# GLEIF Authorized Representative (GAR)

This package contains documentation and Bash shell scripts needed to use the KERIpy command line tool (`kli`) to
participate as a GLEIF Authorized Representative (GAR) as a member of the GLEIF External Autonomic Identifier (AID) or
the GLEIF Internal Autonomic Identifier (AID) 

## Repository Layout
This repository contains documentation in the `./docs` directory and Bash shell scripts in the `./scripts` directory.  The 
scripts make it easy to use the KERI command line tool `kli` to perform all functions required of a GAR.  It utilizes the KERI
docker image `gleif/keri:1.1.36` with mounts to local directories to minimize the requirements on the local system.  

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