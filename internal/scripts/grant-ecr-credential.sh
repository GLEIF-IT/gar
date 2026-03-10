#!/bin/bash

##################################################################
##                                                              ##
##          Script for issuing ecr credential                   ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the Alias of the recipient: " -r recipient
read -p "Enter the ECR credential SAID: " -r SAID
read -p "Enter the datetime to use: " -r datetime

kli ipex grant --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --said "${SAID}" --time "${datetime}" --recipient "${recipient}"
