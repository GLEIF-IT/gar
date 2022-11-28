#!/bin/bash

##################################################################
##                                                              ##
##             Script for creating multisig aid                 ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Type or paste a nonce: " -r nonce

kli vc registry incept  --name "${INT_GAR_NAME}" --passcode "${passcode}"  --alias "${INT_GAR_AID_ALIAS}" --registry-name "${INT_GAR_REG_NAME}" --nonce "${nonce}"
