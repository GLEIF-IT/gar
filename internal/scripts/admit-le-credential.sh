#!/bin/bash

##################################################################
##                                                              ##
##             Script for admitting the QVI credential          ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the SAID of the IPEX GRANT for the LE credential: " -r SAID
read -p "Enter the datetime of the IPEX Grant for the LE credential to use: " -r datetime

kli ipex admit \
    --name "${INT_GAR_NAME}" \
    --passcode "${passcode}" \
    --alias "${INT_GAR_AID_ALIAS}" \
    --said "${SAID}" \
    --time "${datetime}"
