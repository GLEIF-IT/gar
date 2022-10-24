#!/bin/bash

##################################################################
##                                                              ##
##        Script for creating local External GAR AID            ##
##                                                              ##
##################################################################

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"
salt="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-salt)"

# Test to see if this script has already been run:
OUTPUT=$(kli list --name "${EXT_GAR_NAME}" --passcode "${EXT_GAR_PASSCODE}")
ret=$?
if [ $ret -eq 0 ]; then
   echo "Local AID for ${EXT_GAR_NAME} already exists, exiting:"
   printf "\t%s\n" "${OUTPUT}"
   exit 69
fi

# Create the local database environment (directories, datastore, keystore)
kli init --name "${EXT_GAR_NAME}" --salt "${salt}" --passcode "${passcode}" --config-file ext-gar-config.json

# Create your local AID for use as a participant in the External AID
kli incept --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_ALIAS}" --passcode "${passcode}" --file /scripts/ext-gar-local-incept.json

# Here's your AID:
kli status --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_ALIAS}" --passcode "${passcode}"