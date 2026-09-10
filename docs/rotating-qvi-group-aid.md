# Rotating the QVI group (multisig) AID

When rotating the QVI group AID then the raw `kli.sh` script and `multisig-join.sh` must be used as follows for the GARs to approve the delegation.
`delegate confirm` prints a key-change summary of the rotation before asking to accept; verify it with the QAR on a call, ending with the event SAID `d`, as described in
[Approving QVI Rotation Events](../external/docs/approving-qvi-rotation.md).

```bash
# GAR 1
./scripts/kli.sh delegate confirm --alias "GLEIF External AID" --interact
# GAR 2
./scripts/multisig-join.s
```