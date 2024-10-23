#!/bin/bash

##################################################################
##                                                              ##
##             Script for IPEX granting QVI credential          ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter the SAID of the new QVI credential: " -r SAID
read -p "Enter the alias of the new QVI: " -r recipient
read -p "Enter the datetime to use: " -r datetime

kli ipex grant \
    --name "${EXT_GAR_NAME}" \
    --passcode "${passcode}" \
    --alias "${EXT_GAR_AID_ALIAS}" \
    --said "${SAID}" \
    --recipient "${recipient}" \
    --time "${datetime}"
