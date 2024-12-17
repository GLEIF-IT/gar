#!/bin/bash

rm -rfv "${HOME}/.gar" # Deletes the entire .gar directory from your home directory.
rm -rfv "${HOME}/.keri" # Deletes the entire .keri directory from your home directory.
mkdir "${HOME}/.gar"

# Deletes the passcode for your local keystore from the Keychain.
passcode_item="$(security find-generic-password -a "${LOGNAME}" -s ext-gar-passcode 2> /dev/null)"
if [ -n "${passcode_item}" ]; then
  echo "Deleting passcode from Keychain"
  security delete-generic-password -a "${LOGNAME}" -s ext-gar-passcode
else
  echo "Passcode not found in Keychain, nothing to delete."
fi

# Deletes the salt for your local keystore from the Keychain.
salt_item="$(security find-generic-password -a "${LOGNAME}" -s ext-gar-salt 2> /dev/null)"
if [ -n "${salt_item}" ]; then
  echo "Deleting salt from Keychain"
  security delete-generic-password -a "${LOGNAME}" -s ext-gar-salt
else
  echo "Salt not found in Keychain, nothing to delete."
fi