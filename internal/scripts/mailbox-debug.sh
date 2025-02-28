#!/bin/bash

##################################################################
##                                                              ##
##  Script for listing MAILBOX notifications                    ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

# Here's your credentials:
kli mailbox debug --name "${INT_GAR_NAME}" --alias "${INT_GAR_AID_ALIAS}" --passcode "${passcode}" "$@"