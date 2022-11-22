#!/bin/bash

##################################################################
##                                                              ##
##        Script for creating local Internal GAR AID            ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"
salt="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-salt)"

# Test to see if this script has already been run:
OUTPUT=$(kli list --name "${INT_GAR_NAME}" --passcode "${passcode}")
ret=$?
if [ $ret -eq 0 ]; then
   echo "Local AID for ${INT_GAR_NAME} already exists, exiting:"
   printf "\t%s\n" "${OUTPUT}"
   exit 69
fi

# Create the local database environment (directories, datastore, keystore)
kli init --name "${INT_GAR_NAME}" --salt "${salt}" --passcode "${passcode}" --config-dir /scripts --config-file int-gar-config.json

# Create your local AID for use as a participant in the Internal AID
kli incept --name "${INT_GAR_NAME}" --alias "${INT_GAR_ALIAS}" --passcode "${passcode}" --file /scripts/int-gar-local-incept.json

# Here's your AID:
kli status --name "${INT_GAR_NAME}" --alias "${INT_GAR_ALIAS}" --passcode "${passcode}"