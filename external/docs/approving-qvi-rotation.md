
# Approving QVI Rotation Events.

This document is intended for GLEIF External Authorized Representatives (External GARs) in their daily interactions with
Qualified vLEI Issuers (QVI). 

This document describes the steps required to authenticate QVI Authorized Representatives (QARs) and 
approve the rotation of their group multisig AID by participating in the creation of a KERI interaction event that contains
a seal of the rotation event for the QVI group multisig AID.

Make sure your context is set with `source source.sh` and `./scripts/prepare.sh`

```bash
./scripts/kli.sh delegate confirm --alias "GLEIF External AID" --interact
```

## Verifying the rotation out of band before accepting

Do this on a call with the QAR. Before asking `Accept [Y|n]?`, the command prints a summary of the rotation event it
found in escrow, for example:

```
Delegation rotation request
  delegate      i  = <QVI group AID>
  delegator     di = <GLEIF External AID>
  sequence      s  = <sequence number, hex as it appears in the event>
  event SAID    d  = <SAID of the rotation event>
Signing keys (kt: <prior threshold> -> <new threshold>)
    unchanged: ...
    added:     ...
    removed:   ...
Next key digests (nt: <prior threshold> -> <new threshold>)
    unchanged: ...
    added:     ...
    removed:   ...
Witnesses (bt: <new witness threshold>)
    cuts: ...
    adds: ...
```

The lists are computed against the QVI AID's current key state as your keystore knows it, so a routine rotation shows
every prior signing key under `removed`, every new one under `added`, and the previous next-key digests under
`removed` with the new ones under `added`. Thresholds are printed exactly as they appear; for a multisig AID they may be
lists of fractions.

1. The QAR reads out, from their side, the new signing keys, the new next-key digests, the signing and next thresholds,
   and any witness cuts or adds in the rotation they created.
2. Compare each against the printed summary. Every value must match in full; do not compare only the first few
   characters.
3. Both of you then read out the event SAID `d`. `d` is the SAID of the whole rotation event, so a matching `d` covers
   every other field in the event, including the ones above. The seal you are about to anchor in your interaction event
   is exactly `i`, `s`, `d`.
4. Only when `d` matches, answer `Y`. If anything differs, answer `n` and resolve the discrepancy with the QAR before
   trying again.

The summary is also printed when running with `--auto`, so it appears in logs even when no prompt is shown.
