#!/bin/bash

##################################################################
##                                                              ##
##          Script for issuing oor auth                         ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the Alias of Sally to present this credential to: " -r recipient
read -p "Enter the datetime to use: " -r datetime
read -p "Enter the OOR credential SAID: " -r SAID

kli ipex grant \
    --name "${INT_GAR_NAME}" \
    --alias "${INT_GAR_ALIAS}" \
    --passcode "${passcode}" \
    --said "${SAID}" \
    --time "${datetime}" \
    --recipient "${recipient}"
