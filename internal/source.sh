#!/bin/bash

##################################################################
##                                                              ##
##          Initialization script for Internal GAR              ##
##                                                              ##
##################################################################

# Change to the name you want to use for your local database environment.
export INT_GAR_NAME="Internal GAR"

# Change to the name you want for the alias for your local Internal GAR AID
export INT_GAR_ALIAS="John Doe"

# Change to the name you want for the alias for your group multisig Internal AID
export INT_GAR_AID_ALIAS="GLEIF Internal AID"

# Change to the name you want for the alias for your group multisig Internal AID
export INT_GAR_REG_NAME="Internal GAR Registry"

# Set current working directory for all scripts that must access files
INT_GAR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

export INT_GAR_SCRIPT_DIR="${INT_GAR_DIR}/scripts"
export INT_GAR_DATA_DIR="${INT_GAR_DIR}/data"

function kli() {
  docker run -it --rm -v "${HOME}"/.gar:/usr/local/var/keri -v "${INT_GAR_SCRIPT_DIR}":/scripts -v "${INT_GAR_DATA_DIR}":/data gleif/keri:0.70 kli "$@"
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