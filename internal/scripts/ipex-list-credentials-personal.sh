#!/bin/bash

##################################################################
##                                                              ##
##                Script for listing credentials                ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

# Here's your credentials:
kli ipex list \
  --name "${INT_GAR_NAME}" \
  --alias "${INT_GAR_ALIAS}" \
  --passcode "${passcode}" \
  --poll  "$@"
