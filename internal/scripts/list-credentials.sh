#!/bin/bash

##################################################################
##                                                              ##
##                Script for listing credentials                ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

# Here's your credentials:
export DEBUG_KLI=1
kli vc list --name "${INT_GAR_NAME}" --passcode "${passcode}" --poll "$@"