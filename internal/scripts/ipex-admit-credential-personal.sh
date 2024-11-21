#!/bin/bash

##################################################################
##                                                              ##
##             Script for admitting a credential with IPEX      ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the SAID of the IPEX GRANT for the credential: " -r SAID
read -p "Enter the datetime of the IPEX Grant for the LE credential to use: " -r datetime

kli ipex admit \
    --name "${INT_GAR_NAME}" \
    --alias "${INT_GAR_ALIAS}" \
    --passcode "${passcode}" \
    --said "${SAID}" \
    --time "${datetime}"
