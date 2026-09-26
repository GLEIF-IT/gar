#!/usr/bin/env python3
"""
Make outgoing IPEX grants and admits, and challenge responses, carry their
recipient in the exn's top-level 'rp' field, not only in the legacy 'a.i'
attribute.

keripy 1.1.25 added the required 'rp' (recipient) field to exchange (exn)
messages, but the 1.1.x exn builder hardcodes it to "" and only ever fills the
payload attribute 'a.i'. keripy 1.2.0 (commit c1163dd55) taught the builder to
fill 'rp' from its `recipient` argument, yet the IPEX builders in every keripy
release to date, 1.2.14 and main included, still never pass one, and neither
does `kli challenge respond`. So every grant and challenge response a kli user
sends has "rp": "". Signify and KERIA always set 'rp', so every QVI does, and
the GAR kli tooling is the one sender in the ecosystem that does not. Stacks
that route or notify on 'rp' (the Veridian QVI platform, September 2026) then
never see our messages. 'a.i' is left in place for receivers that only read it.

Four edits, applied at image build time (see ../Dockerfile):

  1. exchanging.exchange: set 'rp' from `recipient` when one is given
     (backport of the 1.2.0 behaviour); callers that pass none still get "".
  2. protocoling.ipexGrantExn: pass the grant recipient through, so 'rp' and
     'a.i' both name the issuee.
  3. protocoling.ipexAdmitExn: pass the grant's sender through, so admits we
     send name the issuer in 'rp'.
  4. kli challenge respond: pass the resolved --recipient through, so the
     challenger is named in 'rp'.

'rp' is part of the signed body, so only exns built after this patch change;
nothing already sent or stored is affected. Receivers on 1.1.x and 1.2.x only
log the value, so a populated 'rp' cannot break them.

Fails loudly if the target text is not found exactly once, so a base image
bump surfaces the mismatch instead of silently shipping an unpatched builder.
"""
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "/keripy/src/keri"

EDITS = {
    f"{ROOT}/peer/exchanging.py": [
        (
            '''               rp="",
''',
            '''               rp=recipient if recipient is not None else "",  # backport of keripy 1.2.0 (c1163dd55)
''',
        ),
    ],
    f"{ROOT}/vc/protocoling.py": [
        (
            '''    exn, end = exchanging.exchange(route="/ipex/grant", payload=data, sender=hab.pre, embeds=embeds, date=dt, **kwa)
''',
            '''    exn, end = exchanging.exchange(route="/ipex/grant", payload=data, sender=hab.pre, recipient=recp, embeds=embeds,
                                   date=dt, **kwa)
''',
        ),
        (
            '''    exn, end = exchanging.exchange(route="/ipex/admit", payload=data, sender=hab.pre, dig=grant.said, date=dt)
''',
            '''    exn, end = exchanging.exchange(route="/ipex/admit", payload=data, sender=hab.pre, recipient=grant.ked["i"],
                                   dig=grant.said, date=dt)
''',
        ),
    ],
    f"{ROOT}/app/cli/commands/challenge/respond.py": [
        (
            '''        exn, _ = exchanging.exchange(route="/challenge/response", payload=payload, sender=hab.pre)
''',
            '''        exn, _ = exchanging.exchange(route="/challenge/response", payload=payload, sender=hab.pre, recipient=recp)
''',
        ),
    ],
}

for path, edits in EDITS.items():
    with open(path) as f:
        src = f.read()
    for old, new in edits:
        if new in src:
            continue  # already applied
        if src.count(old) != 1:
            sys.exit(f"exn-set-rp patch: expected text not found exactly once in {path}; "
                     f"base image changed, review this patch against upstream keripy")
        src = src.replace(old, new)
    with open(path, "w") as f:
        f.write(src)
    print(f"exn-set-rp patch applied to {path}")
