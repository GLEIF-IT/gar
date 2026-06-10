#!/bin/bash
set -euo pipefail

PWD=$(pwd)
source "$PWD/source.sh"

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

docker run -it --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${INT_GAR_SCRIPT_DIR}":/scripts \
  -v "${INT_GAR_DATA_DIR}":/data \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  -e DEBUG_KLI="${DEBUG:-}" \
  gleif/keri:1.1.44 \
  /scripts/multisig_rotate_preflight.py \
    --name "${INT_GAR_NAME}" \
    --passcode "${passcode}" \
    "$@"
