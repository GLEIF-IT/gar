#!/bin/bash

##################################################################
##                                                              ##
##     Dev Reset Script - Teardown and recreate External GAR    ##
##     with test pool for development purposes                  ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

BACKUP_DIR="$HOME/.gar-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="$BACKUP_DIR/ext-gar-$TIMESTAMP"

echo "Creating backup directory: $BACKUP_PATH"
mkdir -p "$BACKUP_PATH"

# Export existing keychain secrets to backup
passcode=$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode 2>/dev/null)
salt=$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-salt 2>/dev/null)

if [ -n "$passcode" ] && [ -n "$salt" ]; then
    echo "Backing up keychain secrets..."
    cat > "$BACKUP_PATH/secrets.json" << EOF
{
  "passcode": "$passcode",
  "salt": "$salt",
  "timestamp": "$TIMESTAMP",
  "type": "external"
}
EOF
    echo "Secrets backed up to: $BACKUP_PATH/secrets.json"
else
    echo "No existing keychain secrets found to backup"
fi

# Backup ~/.gar folder if it exists
if [ -d "$HOME/.gar" ]; then
    echo "Backing up ~/.gar directory..."
    cp -r "$HOME/.gar" "$BACKUP_PATH/gar-data"
    echo "GAR data backed up to: $BACKUP_PATH/gar-data"
else
    echo "No existing ~/.gar directory to backup"
fi

# Backup ~/.keri folder if it exists
if [ -d "$HOME/.keri" ]; then
    echo "Backing up ~/.keri directory..."
    cp -r "$HOME/.keri" "$BACKUP_PATH/keri-data"
    echo "KERI data backed up to: $BACKUP_PATH/keri-data"
else
    echo "No existing ~/.keri directory to backup"
fi

echo ""
echo "=== Teardown ==="

# Remove directories
echo "Removing ~/.gar and ~/.keri directories..."
rm -rf "$HOME/.gar"
rm -rf "$HOME/.keri"
mkdir "$HOME/.gar"

# Delete keychain entries
passcode_item="$(security find-generic-password -a "${LOGNAME}" -s ext-gar-passcode 2>/dev/null)"
if [ -n "${passcode_item}" ]; then
    echo "Deleting ext-gar-passcode from Keychain"
    security delete-generic-password -a "${LOGNAME}" -s ext-gar-passcode
else
    echo "Passcode not found in Keychain"
fi

salt_item="$(security find-generic-password -a "${LOGNAME}" -s ext-gar-salt 2>/dev/null)"
if [ -n "${salt_item}" ]; then
    echo "Deleting ext-gar-salt from Keychain"
    security delete-generic-password -a "${LOGNAME}" -s ext-gar-salt
else
    echo "Salt not found in Keychain"
fi

echo ""
echo "=== Setting up new environment ==="

# Re-source to regenerate new secrets in keychain
source $PWD/source.sh

# Get new credentials
passcode=$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)
salt=$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-salt)

echo ""
echo "=== Creating new AID with test pool ==="

# Initialize local database environment
kli init --name "${EXT_GAR_NAME}" --salt "${salt}" --passcode "${passcode}" --config-dir /scripts --config-file test-ext-gar-config.json

# Create local AID with test pool witnesses
kli incept --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_ALIAS}" --passcode "${passcode}" --file /scripts/test-incept-pool-1.json

# Show status
echo ""
echo "=== New AID Status ==="
kli status --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_ALIAS}" --passcode "${passcode}"

echo ""
echo "=== Complete ==="
echo "Backup saved to: $BACKUP_PATH"
echo "New External GAR AID created with test pool"
