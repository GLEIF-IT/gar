Add a new backport-style patch that makes `kli delegate confirm` print a key-change summary before its accept prompt, so an External GAR can verify a QVI's rotation out of band on a call before approving it.

Context
- Both `external/Dockerfile` and `internal/Dockerfile` build from `gleif/keri:1.1.44` and apply the scripts in their `patches/` dirs (`mailbox-debug.py`, `exn-missing-rp.py`). Read `external/patches/exn-missing-rp.py` first and follow its style exactly: a module docstring explaining what and why, an `EDITS` dict of exact-text (old, new) replacements, skip if already applied, `sys.exit` with a clear message if the target text is not found exactly once.
- The two `patches/` dirs are identical. Write the new file once and copy it to both. Add a `RUN python3 /patches/delegate-confirm-summary.py` line to both Dockerfiles after the existing RUN lines.
- Target file inside the image: `/keripy/src/keri/app/cli/commands/delegate/confirm.py`. You can read the exact source with:
  docker run --rm --entrypoint python3 gleif/keri:1.1.44 -c "import inspect; from keri.app.cli.commands.delegate import confirm; print(inspect.getsource(confirm))"
- Note: the 1.1.44 code uses `dkever.delegator` where upstream 1.2.x uses `dkever.delpre`. This prompt is written against 1.1.44. Do not "fix" that name if you cross-reference upstream keripy.

What to change in confirm.py (1.1.44 version)
The accept prompt is currently:

                    if self.auto:
                        approve = True
                    else:
                        yn = input(f"Delegation {typ} request from {eserder.pre}.\nAccept [Y|n]? ")
                        approve = yn in ('', 'y', 'Y')

Insert a summary print before the `if self.auto:` line (print it in both auto and interactive modes). `eserder` is the escrowed dip/drt SerderKERI. For a drt, `dkever = self.hby.kevers[eserder.pre]` is already assigned in the `elif` branch above and holds the delegate's current state: `dkever.verfers` (current signing keys, use `.qb64`), `dkever.ndigers` (current next-key digests, `.qb64`), `dkever.tholder.sith`, `dkever.ntholder.sith`, `dkever.wits`. For a dip there is no prior state; `dkever` is not defined in that branch, so guard on `ilk`.

Print, in this order:
  Delegation <typ> request
    delegate      i  = <eserder.pre>
    delegator     di = <delpre>
    sequence      s  = <eserder.ked["s"]>  (hex, as it appears in the event)
    event SAID    d  = <eserder.said>
  Signing keys (kt: <prior kt> -> <new kt>)
    unchanged / added / removed lists, computed as:
      new keys   = eserder.ked["k"]
      prior keys = [v.qb64 for v in dkever.verfers]  (empty for dip)
      added   = new keys not in prior keys
      removed = prior keys not in new keys
  Next key digests (nt: <prior nt> -> <new nt>)
    same three lists using eserder.ked["n"] vs [d.qb64 for d in dkever.ndigers]
  Witnesses (bt: <eserder.ked["bt"]>)
    cuts: eserder.ked.get("br", [])   adds: eserder.ked.get("ba", [])
    for dip print eserder.ked.get("b", []) as the initial set instead

Print full qb64 values, one per line, indented. Do not truncate. Print "(none)" for empty lists. Thresholds may be ints, hex strings, or lists of fractional strings for multisig; print them with repr-like fidelity, do not try to interpret them.

Then leave the existing `input(...)` prompt unchanged so existing docs and muscle memory still match.

Docs
- Update `external/docs/approving-qvi-rotation.md` (and the one-line mentions in `docs/rotating-qvi-group-aid.md` and `docs/abbreviated.md` if appropriate) to describe the out-of-band check: on the call, the QAR reads their new signing keys, next digests, thresholds, and any witness cuts/adds; the GAR compares against the printed summary; both then read the event SAID `d` to confirm they are looking at the same event; only then answer Y. Note that `d` is the SAID of the whole rotation event, so a matching `d` covers every other field, and that the seal the GAR anchors is exactly `i`, `s`, `d`.

Verification
- Build one of the images via `./scripts/prepare.sh` (or `docker build` on the Dockerfile) and confirm the patch applies cleanly and reports "applied".
- Run `docker run --rm --entrypoint python3 <image> -c "from keri.app.cli.commands.delegate import confirm"` to confirm the patched module still imports.
- Run the patch script a second time against the built image to confirm it is idempotent (prints nothing fatal, skips already-applied edits).
