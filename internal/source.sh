#!/bin/bash

##################################################################
##                                                              ##
##          Initialization script for Internal GAR              ##
##                                                              ##
##################################################################

DEBUG=0

if [ "$1" = "--debug" ]; then
  DEBUG=1
  echo "Debug mode is ON"
fi

if [ ! -f "${HOME}"/.gar/internal.sh ]; then
    cp ./scripts/env.sh "${HOME}"/.gar/internal.sh
fi

source "${HOME}"/.gar/internal.sh

# Set current working directory for all scripts that must access files
INT_GAR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

export INT_GAR_SCRIPT_DIR="${INT_GAR_DIR}/scripts"
export INT_GAR_DATA_DIR="${INT_GAR_DIR}/data"

function kli() {
  docker run -it --rm \
    -v "${HOME}"/.gar:/usr/local/var/keri \
    -v "${INT_GAR_SCRIPT_DIR}":/scripts \
    -v "${INT_GAR_DATA_DIR}":/data \
    -e PYTHONWARNINGS="ignore::SyntaxWarning" \
    -e DEBUG_KLI="${DEBUG}" \
    gleif/keri:enc-notifications "$@"
}

export -f kli

# Creates the passcode for your local keystore and saves it in your keychain.  Will not overwrite
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode 2> /dev/null)"
if [ -z "${passcode}" ]; then
  echo "Generating random passcode and storing in Keychain"
  security add-generic-password -a "${LOGNAME}" -s int-gar-passcode -w "$(kli passcode generate |  tr -d '\r')"
fi

# Creates the salt for your local keystore and saves it in your keychain.  Will not overwrite
salt="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-salt 2> /dev/null)"
if [ -z "${salt}" ]; then
  echo "Generating random salt and storing in Keychain"
  security add-generic-password -a "${LOGNAME}" -s int-gar-salt -w "$(kli salt | tr -d '\r')"
fi