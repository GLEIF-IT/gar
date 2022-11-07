#!/bin/bash

##################################################################
##                                                              ##
##      Script for resolving OOBIs of other participants        ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

read -p "Enter the registry name: " -r reg
read -p "Enter the shared nonce: " -r nonce

kli vc registry incept --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_ALIAS}" --registry-name ${reg} --nonce ${nonce}