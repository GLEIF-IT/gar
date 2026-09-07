#!/usr/bin/env python3
"""
Backport of the upstream keripy fixes to `kli mailbox debug` onto the 1.1.x tree.

Applied at image build time (see ../Dockerfile). Upstream fixed both problems in
keripy PR #805 (first released in 1.2.0):

  1. The command crashed with AttributeError when the keystore had no local
     mailbox index for the (AID, witness) pair yet.
  2. The command only waited for the query to be *transmitted*, then slept one
     second and printed whatever had arrived. Against a remote witness that is
     almost always nothing, so the "Messages:" list came back empty.

This script fails loudly if the target text is not found, so that bumping the
base image surfaces the mismatch instead of silently shipping an unpatched
command. Re-check it against upstream whenever the base image version changes.
"""
import sys

DEFAULT = "/keripy/src/keri/app/cli/commands/mailbox/debug.py"
path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT

EDITS = [
    # 1. Tolerate a missing local index record.
    (
        '''        witrec = hab.db.tops.get((hab.pre, self.witness))
        for topic in witrec.topics:
            print(f"   Topic {topic}:   {witrec.topics[topic]}")
        print()
''',
        '''        witrec = hab.db.tops.get((hab.pre, self.witness))
        if witrec:
            for topic in witrec.topics:
                print(f"   Topic {topic}:   {witrec.topics[topic]}")
        else:
            print("   No local index")
        print()
''',
    ),
    # 2. Wait for the first SSE event (bounded), then keep draining while
    #    events are still streaming in, instead of a fixed one second sleep.
    (
        '''        while client.requests:
            yield self.tock

        yield 1.0
        print("Messages:")
        while client.events:
            evt = client.events.popleft()
            if "id" not in evt or "data" not in evt or "name" not in evt:
                print(f"bad mailbox event: {evt}")
                continue
            idx = evt["id"]
            msg = evt["data"]
            tpc = evt["name"]

            if not self.verbose:
                print(f"Topic {tpc}: {idx}: {msg[0:20]}")
            else:
                print(f"  Topic: {tpc}")
                print(f"  Index: {idx}")
                print(f"  {msg}")
                print()

        self.remove([self.hbyDoer, clientDoer])
''',
        '''        # Wait for the request to go out and then for the first event to arrive,
        # giving up after a bounded time if the mailbox is empty.
        started = self.tyme
        while client.requests or (not client.events and self.tyme - started < 10.0):
            yield self.tock

        print("Messages:")
        count = 0
        while True:
            while client.events:
                evt = client.events.popleft()
                if "id" not in evt or "data" not in evt or "name" not in evt:
                    print(f"bad mailbox event: {evt}")
                    continue
                idx = evt["id"]
                msg = evt["data"]
                tpc = evt["name"]
                count += 1

                if not self.verbose:
                    print(f"Topic {tpc}: {idx}: {msg[0:20]}")
                else:
                    print(f"  Topic: {tpc}")
                    print(f"  Index: {idx}")
                    print(f"  {msg}")
                    print()

            yield 1.0  # let any remaining events stream in before deciding we are done
            if not client.events:
                break

        if count == 0:
            print("   (none)")

        self.remove([self.hbyDoer, clientDoer])
''',
    ),
]

with open(path) as f:
    src = f.read()

for old, new in EDITS:
    if new in src:
        continue  # already applied
    if src.count(old) != 1:
        sys.exit(f"mailbox-debug patch: expected text not found exactly once in {path}; "
                 f"base image changed, review this patch against upstream keripy")
    src = src.replace(old, new)

with open(path, "w") as f:
    f.write(src)
print(f"mailbox-debug patch applied to {path}")
