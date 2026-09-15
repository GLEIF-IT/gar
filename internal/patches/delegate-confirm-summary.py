#!/usr/bin/env python3
"""
Make `kli delegate confirm` print a key-change summary before its accept prompt.

An External GAR approving a QVI rotation gets only "Delegation rotation request
from <AID>. Accept [Y|n]?" and has no way to check, on the call with the QAR,
that the event they are anchoring is the one the QVI actually made. This patch
prints, before that prompt (in both interactive and --auto mode), the delegate
AID, delegator, sequence number and event SAID, then the signing keys, next key
digests and witness changes as unchanged / added / removed lists against the
delegate's current key state. The GAR reads these back with the QAR and then
both confirm the event SAID `d`, which covers every other field.

Applied at image build time (see ../Dockerfile) to keripy 1.1.44, where the
delegator prefix lives on `dkever.delegator` (upstream 1.2.x renamed it
`delpre`; do not "fix" that here). Two edits:

  1. Insert a call to a new printSummary() right before the accept prompt.
  2. Add printSummary() as a static method on ConfirmDoer.

The existing input() prompt text is left unchanged so docs still match.

Fails loudly if the target text is not found exactly once, so a base image bump
surfaces the mismatch instead of silently shipping an unpatched command.
"""
import sys

DEFAULT = "/keripy/src/keri/app/cli/commands/delegate/confirm.py"
path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT

EDITS = [
    # 1. Print the summary before the accept prompt, in both auto and interactive modes.
    (
        '''                if delpre in self.hby.prefixes:
                    hab = self.hby.habs[delpre]

                    if self.auto:
                        approve = True
                    else:
                        yn = input(f"Delegation {typ} request from {eserder.pre}.\\nAccept [Y|n]? ")
                        approve = yn in ('', 'y', 'Y')
''',
        '''                if delpre in self.hby.prefixes:
                    hab = self.hby.habs[delpre]

                    # dkever is only assigned in the drt branch above; for a dip
                    # there is no prior key state to diff against.
                    self.printSummary(eserder=eserder, typ=typ, delpre=delpre,
                                      dkever=dkever if ilk in (coring.Ilks.drt,) else None)

                    if self.auto:
                        approve = True
                    else:
                        yn = input(f"Delegation {typ} request from {eserder.pre}.\\nAccept [Y|n]? ")
                        approve = yn in ('', 'y', 'Y')
''',
    ),
    # 2. The summary printer itself.
    (
        '''    def escrowed(self):
        esc = []
''',
        '''    @staticmethod
    def printSummary(eserder, typ, delpre, dkever=None):
        """ Print a key-change summary of an escrowed delegated event so the
        delegator can verify it out of band before approving it.

        Parameters:
            eserder (SerderKERI): the escrowed dip or drt event
            typ (str): "inception" or "rotation"
            delpre (str): delegator prefix
            dkever (Kever | None): delegate's current key state for a rotation,
                None for an inception (no prior state)
        """
        ked = eserder.ked

        def show(label, items):
            print(f"    {label}:")
            if not items:
                print("      (none)")
            for item in items:
                print(f"      {item}")

        def diff(prior, new):
            unchanged = [x for x in new if x in prior]
            added = [x for x in new if x not in prior]
            removed = [x for x in prior if x not in new]
            return unchanged, added, removed

        if dkever is not None:
            priorKeys = [verfer.qb64 for verfer in dkever.verfers]
            priorDigs = [diger.qb64 for diger in dkever.ndigers]
            priorKt = dkever.tholder.sith
            priorNt = dkever.ntholder.sith
        else:
            priorKeys, priorDigs, priorKt, priorNt = [], [], None, None

        print(f"Delegation {typ} request")
        print(f"  delegate      i  = {eserder.pre}")
        print(f"  delegator     di = {delpre}")
        print(f"  sequence      s  = {ked['s']}")
        print(f"  event SAID    d  = {eserder.said}")

        unchanged, added, removed = diff(priorKeys, ked.get("k", []))
        print(f"Signing keys (kt: {priorKt!r} -> {ked.get('kt')!r})")
        show("unchanged", unchanged)
        show("added", added)
        show("removed", removed)

        unchanged, added, removed = diff(priorDigs, ked.get("n", []))
        print(f"Next key digests (nt: {priorNt!r} -> {ked.get('nt')!r})")
        show("unchanged", unchanged)
        show("added", added)
        show("removed", removed)

        print(f"Witnesses (bt: {ked.get('bt')!r})")
        if dkever is not None:
            show("cuts", ked.get("br", []))
            show("adds", ked.get("ba", []))
        else:
            show("initial set", ked.get("b", []))
        print()

    def escrowed(self):
        esc = []
''',
    ),
]

with open(path) as f:
    src = f.read()

for old, new in EDITS:
    if new in src:
        continue  # already applied
    if src.count(old) != 1:
        sys.exit(f"delegate-confirm-summary patch: expected text not found exactly once in {path}; "
                 f"base image changed, review this patch against upstream keripy")
    src = src.replace(old, new)

with open(path, "w") as f:
    f.write(src)
print(f"delegate-confirm-summary patch applied to {path}")
