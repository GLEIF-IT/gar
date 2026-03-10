#!/bin/bash

##################################################################
##                                                              ##
##          Script for revoking qvi                             ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter the credential SAID: " -r SAID
read -p "Enter the datetime to use: " -r datetime

kli vc revoke --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_AID_ALIAS}" --registry-name "${EXT_GAR_REG_NAME}" --said "${SAID}" --time "${datetime}"