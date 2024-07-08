#!/bin/bash

##################################################################
##                                                              ##
##             Script for creating multisig aid                 ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter the SAID of the new QVI credential: " -r SAID
read -p "Enter the alias of the new QVI: " -r recipient

kli ipex grant --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_AID_ALIAS}" --said "${SAID}" --recipient "${recipient}"
