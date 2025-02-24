#!/bin/bash

##################################################################
##                                                              ##
##  Script for listing escrows                                  ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# Here's your credentials:
kli escrow list --name "${EXT_GAR_NAME}" --passcode "${passcode}" "$@"