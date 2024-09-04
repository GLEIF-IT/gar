#!/bin/bash

##################################################################
##                                                              ##
##        Script for creating local External GAR AID            ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"
salt="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-salt)"

# Test to see if this script has already been run:
OUTPUT=$(kli list --name "${EXT_GAR_NAME}" --passcode "${passcode}")
ret=$?
if [ $ret -eq 0 ]; then
   echo "Local AID for ${EXT_GAR_NAME} already exists, exiting:"
   printf "\t%s\n" "${OUTPUT}"
   exit 69
fi

echo "Please select witness pool:"
echo "1) Pool 1"
echo "2) Pool 2"
echo "3) Test Pool"
read -p "Enter pool number: " -r pool

p=""
c=""
case $pool in
  1 | "Pool 1")
    p=ext-gar-local-incept-pool-1.json
    c=ext-gar-config.json
    ;;
  2 | "Pool 2")
    p=ext-gar-local-incept-pool-2.json
    c=ext-gar-config.json
    ;;
  3 | "Test Pool")
    p=test-incept-pool-1.json
    c=test-ext-gar-config.json
    ;;
  *)
    echo 1>&2 "$pool: invalid pool selection"
    exit 2
    ;;
esac

# Create the local database environment (directories, datastore, keystore)
kli init --name "${EXT_GAR_NAME}" --salt "${salt}" --passcode "${passcode}" --config-dir /scripts --config-file $c

# Create your local AID for use as a participant in the External AID
kli incept --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_ALIAS}" --passcode "${passcode}" --file /scripts/$p

# Here's your AID:
kli status --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_ALIAS}" --passcode "${passcode}"