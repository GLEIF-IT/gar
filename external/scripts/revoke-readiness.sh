#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  For each credential the group AID has issued: can THIS GAR  ##
##  take part in revoking it, and if not what is missing        ##
##  (credential body, TEL issuance, registry not adopted).      ##
##  Lists only the problems unless --all. Read-only.            ##
##                                                              ##
##  Usage:  revoke-readiness.sh                                 ##
##          revoke-readiness.sh <manifest.json>  [--all|--json] ##
##            compare against another GAR's export              ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

mounts=()
args=()
for a in "$@"; do
  case "$a" in
    --all|--json|-j) args+=("$a") ;;
    *)
      [ -f "$a" ] || { echo "usage: revoke-readiness.sh [manifest.json] [--all] [--json]" >&2; exit 2; }
      mounts=(-v "$(cd "$(dirname "$a")" && pwd)/$(basename "$a")":/import/manifest.json:ro)
      args+=(--manifest /import/manifest.json)
      ;;
  esac
done

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# No tty: never prompts, and --json output is a plain byte stream safe for jq.
docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${EXT_GAR_SCRIPT_DIR}":/scripts \
  ${mounts[@]+"${mounts[@]}"} \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/revoke_readiness.py --name "${EXT_GAR_NAME}" --passcode "${passcode}" \
    --alias "${EXT_GAR_AID_ALIAS}" --registry-name "${EXT_GAR_REG_NAME}" ${args[@]+"${args[@]}"}
