#!/bin/bash

##################################################################
##                                                              ##
##          Initialization script for External GAR              ##
##                                                              ##
##################################################################

EXT_GAR_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export EXT_GAR_SCRIPT_DIR

alias kli="docker run -it --rm -v \"${HOME}\"/.gar:/usr/local/var/keri \"${EXT_GAR_SCRIPT_DIR}\":/scripts gleif/keri:0.6.7 kli"

# Set current working directory for all scripts that must access files
# Change to the name you want to use for your local database environment.
export EXT_GAR_NAME="External GAR"

# Change to the name you want for the alias for your local External GAR AID
export EXT_GAR_ALIAS="Phil Feairheller"

# Creates the passcode for your local keystore and saves it in your keychain.  Will not overwrite
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode 2> /dev/null)"
if [ -z "${passcode}" ]; then
  echo "Generating random passcode and storing in Keychain"
  security add-generic-password -a "${LOGNAME}" -s ext-gar-passcode -w "$(kli passcode generate)"
fi

# Creates the salt for your local keystore and saves it in your keychain.  Will not overwrite
salt="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-salt 2> /dev/null)"
if [ -z "${salt}" ]; then
  echo "Generating random salt and storing in Keychain"
  security add-generic-password -a "${LOGNAME}" -s ext-gar-salt -w "$(kli salt)"
fi