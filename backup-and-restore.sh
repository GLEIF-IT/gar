#!/bin/bash
# backup-and-restore.sh
# Back up the salt, passcode, ~/.gar directory, and the configuration used for witnesses, inception, anchors, and multisig.
# Store the backup in $GLEIF_HOME/qvi-qualifications/backup by filename like:
# gar-backup-<qvi-client>-<date>.tar.gz
# For example:
#   gar-backup-cfca-2024-12-19.tar.gz

# Check for GLEIF_HOME
if [ -z "$GLEIF_HOME" ]; then
    echo "GLEIF_HOME environment variable not set"
    exit 1
fi

# Check if ~/$GLEIF_HOME/qvi-qualifications exists
QUALIFICATIONS_DIR="$GLEIF_HOME/qvi-qualifications"
BACKUPS_DIR="$QUALIFICATIONS_DIR/backups"
if [ ! -d "$GLEIF_HOME/qvi-qualifications" ]; then
    echo "Creating $QUALIFICATIONS_DIR"
    mkdir -p "$BACKUPS_DIR"
fi

# check if clients.json exists. if not, create it
if [ ! -f "$BACKUPS_DIR/clients.json" ]; then
    echo "Creating $BACKUPS_DIR/clients.json"
    echo '{"clients":{}}' > "$BACKUPS_DIR/clients.json"
fi

# ask user for client name
DATE=$(date +%Y-%m-%d)


# Functions
function create_backup() {
    CLIENT_NAME=$1
    echo "Creating backup for $CLIENT_NAME"
    # check if backup already exists
    backup_name=$(jq --arg clientname cfca '.clients[$clientname]' $GLEIF_HOME/qvi-qualifications/backups/clients.json)
    echo backup name is $backup_name
    if [ ! -z "$backup_name" ]; then
        echo "Backup for $CLIENT_NAME already exists: $backup_name"
        echo "Want to override it? (y/N)"
        read -r OVERRIDE
        if [ "$OVERRIDE" != "y" ]; then
            echo "Exiting..."
            exit 0    
        else
            echo "Overriding backup for $CLIENT_NAME"
        fi
    fi

    ext_passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"
    ext_salt="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-salt 2> /dev/null)"
    int_passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"
    int_salt="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-salt 2> /dev/null)"

    echo "Backing up internal and external GAR salt, passcode, ~/.gar"

    BACKUP_NAME="gar-backup-$CLIENT_NAME-$DATE"

    echo "Creating backup for $CLIENT_NAME to"
    echo "$BACKUPS_DIR/$BACKUP_NAME.tar.gz"

    BACKUP_DIR=$BACKUPS_DIR/tmp/$BACKUP_NAME
    mkdir -p $BACKUP_DIR

    read -r -d '' gar_identity_config << EOM
{
    "client": "$CLIENT_NAME",
    "date": "$DATE",
    "extPasscode": "$ext_passcode",
    "extSalt": "$ext_salt",
    "intPasscode": "$int_passcode",
    "intSalt": "$int_salt"
}
EOM

    echo $gar_identity_config

    touch $BACKUP_DIR/gar-identity-config.json
    echo $gar_identity_config > $BACKUP_DIR/gar-identity-config.json

    #
    # copy all the necessary files to the backup directory
    #
    EXT_SCRIPTS_DIR=$BACKUP_DIR/external/scripts
    EXT_CONF_DIR=$EXT_SCRIPTS_DIR/keri/cf
    EXT_DATA_DIR=$BACKUP_DIR/external/data
    mkdir -p $EXT_CONF_DIR
    mkdir -p $EXT_DATA_DIR

    INT_SCRIPTS_DIR=$BACKUP_DIR/internal/scripts
    INT_CONF_DIR=$INT_SCRIPTS_DIR/keri/cf
    INT_DATA_DIR=$BACKUP_DIR/internal/data
    mkdir -p $INT_CONF_DIR
    mkdir -p $INT_DATA_DIR

    # Copy external
    cp ./external/data/* $EXT_DATA_DIR
    cp ./external/scripts/keri/cf/* $EXT_CONF_DIR
    cp ./external/scripts/anchor.json $EXT_SCRIPTS_DIR/anchor.json
    cp ./external/scripts/env.sh $EXT_SCRIPTS_DIR/env.sh
    cp ./external/scripts/test-incept-pool-1.json $EXT_SCRIPTS_DIR/test-incept-pool-1.json

    # Copy internal
    cp ./internal/data/* $INT_DATA_DIR
    cp ./internal/scripts/keri/cf/* $INT_CONF_DIR
    cp ./internal/scripts/anchor.json $INT_SCRIPTS_DIR/anchor.json
    cp ./internal/scripts/env.sh $INT_SCRIPTS_DIR/env.sh
    cp ./internal/scripts/test-incept-pool-1.json $INT_SCRIPTS_DIR/test-incept-pool-1.json

    # Copy ~/.gar folder
    cp -r ~/.gar $BACKUP_DIR/.gar

    # Create the tarball
    tar -czf $BACKUPS_DIR/$BACKUP_NAME.tar.gz -C $BACKUPS_DIR/tmp $BACKUP_NAME
    # Remove the temp files
    rm -rf $BACKUPS_DIR/tmp

    # Update the name of the backup in the clients.json file
    tmp=$(mktemp)
    jq --arg clientname $CLIENT_NAME \
        --arg backup $BACKUP_NAME \
        '.clients |= . + {$clientname: $backup}' $BACKUPS_DIR/clients.json > $tmp
    mv $tmp $BACKUPS_DIR/clients.json
    echo "Backup of $CLIENT_NAME complete"
}

function restore_backup() {
    CLIENT_NAME=$1

    echo
    echo "Restoring backup"
    mkdir -p $BACKUPS_DIR/restore_tmp
    # if restore dir already exists then clear it out
    rm -rf $BACKUPS_DIR/restore_tmp/*

    # get name of backup and decompress archive
    backup_name=$(jq --arg clientname $CLIENT_NAME '.clients[$clientname]' $GLEIF_HOME/qvi-qualifications/backups/clients.json | tr -d '"')
    echo "Restoring backup $backup_name for $CLIENT_NAME"
    echo
    tar -xzf $BACKUPS_DIR/$backup_name.tar.gz -C $BACKUPS_DIR/restore_tmp
    backup_date=$(jq '.date' $BACKUPS_DIR/restore_tmp/$backup_name/gar-identity-config.json | tr -d '"')
    echo "Restoring $CLIENT_NAME backup from $backup_date"

    # print passcode
    ext_passcode=$(jq '.extPasscode' $BACKUPS_DIR/restore_tmp/$backup_name/gar-identity-config.json | tr -d '"')
    ext_salt=$(jq '.extSalt' $BACKUPS_DIR/restore_tmp/$backup_name/gar-identity-config.json | tr -d '"')
    int_passcode=$(jq '.intPasscode' $BACKUPS_DIR/restore_tmp/$backup_name/gar-identity-config.json | tr -d '"')
    int_salt=$(jq '.intSalt' $BACKUPS_DIR/restore_tmp/$backup_name/gar-identity-config.json | tr -d '"')
    
    echo

    # If external passcode and salt are not empty, restore them
    if [ ! -z "$ext_passcode" ] && [ ! -z "$ext_salt" ] ; then
        echo the ext passcode and salt are non empty
        echo "External Passcode: $ext_passcode"
        echo "External Salt: $ext_salt"

        echo "Deleting External Passcode from Keychain"
        security delete-generic-password -a "${LOGNAME}" -s ext-gar-passcode
        echo "Deleting External Salt from Keychain"
        security delete-generic-password -a "${LOGNAME}" -s ext-gar-salt

        echo "Restoring $CLIENT_NAME External Passcode to Keychain"
        security add-generic-password -a "${LOGNAME}" -s ext-gar-passcode -w $ext_passcode
        echo "Restoring $CLIENT_NAME External Salt to Keychain"
        security add-generic-password -a "${LOGNAME}" -s ext-gar-salt -w $ext_salt
    fi

    # If internal passcode and salt are not empty, restore them
    if [ ! -z "$int_passcode" ] && [ ! -z "$int_salt" ] ; then
        echo the int passcode and salt are non empty
        echo "Internal Passcode: $int_passcode"
        echo "Internal Salt: $int_salt"

        echo "Deleting Internal Passcode from Keychain"
        security delete-generic-password -a "${LOGNAME}" -s int-gar-passcode
        echo "Deleting Internal Salt from Keychain"
        security delete-generic-password -a "${LOGNAME}" -s int-gar-salt

        echo "Restoring $CLIENT_NAME Internal Passcode to Keychain"
        security add-generic-password -a "${LOGNAME}" -s int-gar-passcode -w $int_passcode
        echo "Restoring $CLIENT_NAME Internal Salt to Keychain"
        security add-generic-password -a "${LOGNAME}" -s int-gar-salt -w $int_salt
    fi

    echo 

    # Clear out and restore the ~/.gar directory
    echo "Clearing out ~/.gar"
    rm -rfv ~/.gar
    mkdir ~/.gar
    cp -rv $BACKUPS_DIR/restore_tmp/$backup_name/.gar ~/.gar

    # Restore external data, scripts, and config
    echo "Restoring external data, scripts, and config"
    cp -rv $BACKUPS_DIR/restore_tmp/$backup_name/external/data/* ./external/data
    cp -rv $BACKUPS_DIR/restore_tmp/$backup_name/external/scripts/keri/cf/* ./external/scripts/keri/cf
    cp -v $BACKUPS_DIR/restore_tmp/$backup_name/external/scripts/anchor.json ./external/scripts/anchor.json
    cp -v $BACKUPS_DIR/restore_tmp/$backup_name/external/scripts/env.sh ./external/scripts/env.sh
    cp -v $BACKUPS_DIR/restore_tmp/$backup_name/external/scripts/test-incept-pool-1.json ./external/scripts/test-incept-pool-1.json

    # Restore internal data, scripts, and config
    echo "Restoring internal data, scripts, and config"
    cp -rv $BACKUPS_DIR/restore_tmp/$backup_name/internal/data/* ./internal/data
    cp -rv $BACKUPS_DIR/restore_tmp/$backup_name/internal/scripts/keri/cf/* ./internal/scripts/keri/cf
    cp -v $BACKUPS_DIR/restore_tmp/$backup_name/internal/scripts/anchor.json ./internal/scripts/anchor.json
    cp -v $BACKUPS_DIR/restore_tmp/$backup_name/internal/scripts/env.sh ./internal/scripts/env.sh
    cp -v $BACKUPS_DIR/restore_tmp/$backup_name/internal/scripts/test-incept-pool-1.json ./internal/scripts/test-incept-pool-1.json

    # Clean up
    # rm -rf $BACKUPS_DIR/restore_tmp/*

    echo "Restore of $CLIENT_NAME backup $backup_name complete"
}


# Menu options
echo "Select an option:"
echo "1) List existing backups"
echo "2) Create a new backup"
echo "3) Restore a backup - WARNING: This will overwrite the current state"
read -p "Enter the option number: " -r OPTION

case $OPTION in
    1)
        echo "Listing existing backups"
        jq '.clients' $GLEIF_HOME/qvi-qualifications/backups/clients.json
        exit 0
        ;;
    2)
        echo "Creating a new backup"
        read -p "Enter the client name: " -r CLIENT
        create_backup $CLIENT
        ;;
    3)
        echo "Restoring a backup"
        read -p "Enter the client name: " -r CLIENT
        restore_backup $CLIENT
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
