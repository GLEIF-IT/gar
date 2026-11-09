#!/usr/bin/env python3
"""
Print the SAID of the QVI credential a parameters file (prepare-qvi-credential.sh) describes: issued by the
group, same schema, same issuee AID, LEI and dt. Reads the credential bodies (reger.creds), not the saved
index, so it also finds a credential this keystore co-signed but never saved.
Exit 1 with a message on stderr if none or more than one match.
"""
import argparse
import json
import sys

from keri.app.cli.common import existing
from keri.vdr import credentialing


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True)
    p.add_argument("--passcode", dest="bran", default=None)
    p.add_argument("--alias", required=True)
    p.add_argument("--params", required=True)
    args = p.parse_args()
    with open(args.params) as f:
        params = json.load(f)
    hby = existing.setupHby(name=args.name, bran=args.bran)
    try:
        ghab = hby.habByName(args.alias)
        if ghab is None:
            print(f"alias {args.alias!r} not found", file=sys.stderr)
            return 2
        rgy = credentialing.Regery(hby=hby, name=hby.name, base=hby.base)
        hits = []
        for (said,), creder in rgy.reger.creds.getItemIter():
            sad = creder.sad
            a = sad.get("a") if isinstance(sad.get("a"), dict) else {}
            if (sad.get("i") == ghab.pre and sad.get("s") == params["schema"]
                    and a.get("dt") == params["createTime"]
                    and a.get("i") == params["recipient"]
                    and all(a.get(k) == v for k, v in params["data"].items())):
                hits.append(sad["d"])
        if len(hits) != 1:
            print(f"{len(hits)} credential(s) in this keystore match {args.params}"
                  + (": " + ", ".join(hits) if hits else ": run create-qvi-credential.sh with this file first"),
                  file=sys.stderr)
            return 1
        print(hits[0])
        return 0
    finally:
        hby.close()


if __name__ == "__main__":
    sys.exit(main())
