#!/bin/bash

##################################################################
##                                                              ##
##          Initialization script for External GAR              ##
##                                                              ##
##################################################################

if [ ! -f "${HOME}"/.gar/external.sh ]; then
    cp ./scripts/env.sh "${HOME}"/.gar/external.sh
fi

source "${HOME}"/.gar/external.sh

# Set current working directory for all scripts that must access files
EXT_GAR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

export EXT_GAR_SCRIPT_DIR="${EXT_GAR_DIR}/scripts"
export EXT_GAR_DATA_DIR="${EXT_GAR_DIR}/data"

function kli() {
  docker run -it --rm -v "${HOME}"/.gar:/usr/local/var/keri -v "${EXT_GAR_SCRIPT_DIR}":/scripts -v "${EXT_GAR_DATA_DIR}":/data weboftrust/keri:1.1.11 "$@"
}

export -f kli

# Creates the passcode for your local keystore and saves it in your keychain.  Will not overwrite
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode 2> /dev/null)"
if [ -z "${passcode}" ]; then
  echo "Generating random passcode and storing in Keychain"
  security add-generic-password -a "${LOGNAME}" -s ext-gar-passcode -w "$(kli passcode generate |  tr -d '\r')"
fi

# Creates the salt for your local keystore and saves it in your keychain.  Will not overwrite
salt="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-salt 2> /dev/null)"
if [ -z "${salt}" ]; then
  echo "Generating random salt and storing in Keychain"
  security add-generic-password -a "${LOGNAME}" -s ext-gar-salt -w "$(kli salt | tr -d '\r')"
fi