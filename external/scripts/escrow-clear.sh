#!/bin/bash

##################################################################
##                                                              ##
##  Script for clearing escrows                                 ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# Here's your credentials:
kli escrow clear --name "${EXT_GAR_NAME}" --passcode "${passcode}" "$@"