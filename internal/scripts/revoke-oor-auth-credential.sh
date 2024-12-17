#!/bin/bash

##################################################################
##                                                              ##
##          Script for revoking oor auth                        ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the datetime to use: " -r datetime
read -p "Enter the Auth credential SAID: " -r SAID

kli vc revoke --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --registry-name "${INT_GAR_REG_NAME}" --said "${SAID}" --time "${datetime}"