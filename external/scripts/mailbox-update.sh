#!/bin/bash

##################################################################
##                                                              ##
##  Script for listing MAILBOX notifications                    ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# Here's your credentials:
kli mailbox update --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_AID_ALIAS}" --passcode "${passcode}" "$@"