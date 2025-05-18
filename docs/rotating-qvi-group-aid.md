# Rotating the QVI group (multisig) AID

When rotating the QVI group AID then the raw `kli.sh` script and `multisig-join.sh` must be used as follows for the GARs to approve the delegation.

```bash
# GAR 1
./scripts/kli.sh delegate confirm --alias "GLEIF External AID" --interact
# GAR 2
./scripts/multisig-join.s
```