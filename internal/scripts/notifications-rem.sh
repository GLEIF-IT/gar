#!/bin/bash

##################################################################
##                                                              ##
##  Remove a notification by its rid (see notifications-list).  ##
##  Usage: notifications-rem.sh --rid <rid>                     ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

kli notifications rem --name "${INT_GAR_NAME}" --passcode "${passcode}" "$@"
