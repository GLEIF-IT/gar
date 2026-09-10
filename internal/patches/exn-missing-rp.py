#!/usr/bin/env python3
"""
Backport of keripy commit 4bcd89712 ("allow missing 'rp' field in exn message",
first released in 1.2.12) onto the 1.1.x tree.

keripy 1.1.25 added a required recipient field, 'rp', to exchange (exn)
messages. Senders built on older KERI stacks (some KERIA / Signify clients
included) still emit exn messages without it. keripy 1.1.44 rejects those at
parse time with "Missing one or more required fields" and silently drops them,
so challenge responses, IPEX grants and admits from such senders never arrive.

Three edits, applied at image build time (see ../Dockerfile):

  1. serdering, generic required-field check: tolerate an exn whose only
     missing field is 'rp'.
  2. serdering, KERI-specific top-level field-list check: same tolerance.
  3. exchanging: read 'rp' with a default when logging a saved exn, since the
     original indexes the field directly and would raise KeyError.

Fails loudly if the target text is not found, so a base image bump surfaces
the mismatch instead of silently shipping an unpatched parser.
"""
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "/keripy/src/keri"

EDITS = {
    f"{ROOT}/core/serdering.py": [
        (
            '''        if list(alls.keys()) != keys:  # forces ordering of labels in .sad
            raise MissingFieldError(f"Missing one or more required fields from"
                                    f"= {list(alls.keys())} in sad = "
                                    f"{self._sad}.")
''',
            '''        required = list(alls.keys())
        # Backport of keripy 4bcd89712: senders on pre-1.1.25 stacks omit the
        # 'rp' field from exn messages. Tolerate that one missing field.
        if self.ilk == Ilks.exn and "rp" in required and "rp" not in self._sad:
            required.remove("rp")

        if required != keys:  # forces ordering of labels in .sad
            raise MissingFieldError(f"Missing one or more required fields from"
                                    f"= {required} in sad = "
                                    f"{self._sad}.")
''',
        ),
    ],
    f"{ROOT}/core/serdering.py:keri": [
        (
            '''        allkeys = list(self.Fields[self.proto][self.vrsn][self.ilk].alls.keys())
        keys = list(self.sad.keys())
        if allkeys != keys:
''',
            '''        allkeys = list(self.Fields[self.proto][self.vrsn][self.ilk].alls.keys())
        keys = list(self.sad.keys())
        # Backport of keripy 4bcd89712: tolerate exn messages without 'rp'.
        if self.ilk == Ilks.exn and "rp" in allkeys and "rp" not in keys:
            allkeys.remove("rp")
        if allkeys != keys:
''',
        ),
    ],
    f"{ROOT}/peer/exchanging.py": [
        (
            '''        recipient = serder.ked['rp']
        sender = serder.ked['i']
''',
            '''        recipient = serder.ked.get('rp', '')
        sender = serder.ked['i']
''',
        ),
    ],
}

for path, edits in EDITS.items():
    path = path.split(":")[0]  # a file may be listed more than once, tagged after ':'
    with open(path) as f:
        src = f.read()
    for old, new in edits:
        if new in src:
            continue  # already applied
        if src.count(old) != 1:
            sys.exit(f"exn-missing-rp patch: expected text not found exactly once in {path}; "
                     f"base image changed, review this patch against upstream keripy")
        src = src.replace(old, new)
    with open(path, "w") as f:
        f.write(src)
    print(f"exn-missing-rp patch applied to {path}")
