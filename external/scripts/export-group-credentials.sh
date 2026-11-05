#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Export every credential the group AID has issued, with the  ##
##  KELs, registry and credential TELs and chained credentials  ##
##  (LE, QVI) they need, as one CESR stream plus a JSON         ##
##  manifest. Another GAR ingests it with import-credential.sh  ##
##  so it can take part in revoking credentials it did not      ##
##  help issue; a new GAR then runs adopt-registry.sh.          ##
##                                                              ##
##  Usage:  export-group-credentials.sh [out-prefix]            ##
##            writes <out-prefix>.cesr and <out-prefix>.json    ##
##            (default data/group-credentials-<timestamp>)      ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

prefix="${1:-${EXT_GAR_DATA_DIR}/group-credentials-$(date -u +%Y%m%dT%H%M%SZ)}"
outdir="$(mkdir -p "$(dirname "${prefix}")" && cd "$(dirname "${prefix}")" && pwd)"
base="$(basename "${prefix}")"

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${EXT_GAR_SCRIPT_DIR}":/scripts \
  -v "${outdir}":/out \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/export_group_credentials.py --name "${EXT_GAR_NAME}" --passcode "${passcode}" \
    --alias "${EXT_GAR_AID_ALIAS}" --out "/out/${base}.cesr" --manifest "/out/${base}.json"

echo ""
echo "wrote ${outdir}/${base}.cesr and ${outdir}/${base}.json"
echo "send both files to the other GAR, which runs:"
echo "  ./scripts/import-credential.sh ${base}.cesr ${base}.json"
echo "  ./scripts/adopt-registry.sh ${base}.json        (only if it has no registry yet)"
echo "  ./scripts/revoke-readiness.sh ${base}.json"
