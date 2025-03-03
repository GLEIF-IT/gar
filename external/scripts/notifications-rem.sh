#!/bin/bash

##################################################################
##                                                              ##
##  Script for removing notifications                           ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

kli notifications rem --name "${EXT_GAR_NAME}" --passcode "${passcode}" "$@"