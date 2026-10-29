#!/bin/bash

##################################################################
##                                                              ##
##  List the notifications `kli multisig join` and `kli ipex    ##
##  list` read. Stale ones make `kli multisig join` exit before ##
##  it has polled for a new /multisig message.                  ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

kli notifications list --name "${INT_GAR_NAME}" --passcode "${passcode}" "$@"
