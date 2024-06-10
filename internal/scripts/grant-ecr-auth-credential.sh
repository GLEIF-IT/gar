#!/bin/bash

##################################################################
##                                                              ##
##          Script for issuing ecr auth                         ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the Alias of the QVI to authorize with this AUTH credential: " -r recipient
read -p "Enter the datetime to use: " -r datetime

SAID=$(kli vc list --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --issued --said --schema EH6ekLjSr8V32WyFbGe1zXjTzFs9PkTYmupJ9H65O14g)
export DEBUG_KLI=1
kli ipex grant --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --said "${SAID}" --time "${datetime}" --recipient "${recipient}"