#!/bin/bash

cat <<EOF > "${HOME}"/.gar/external.sh
# Change to the name you want to use for your local database environment.
export EXT_GAR_NAME="${EXT_GAR_NAME}"

# Change to the name you want for the alias for your local External GAR AID
export EXT_GAR_ALIAS="${EXT_GAR_ALIAS}"

# Change to the name you want for the alias for your group multisig External AID
export EXT_GAR_AID_ALIAS="${EXT_GAR_AID_ALIAS}"

# Change to the name you want for the alias for your group multisig External AID
export EXT_GAR_REG_NAME="${EXT_GAR_REG_NAME}"
EOF

chmod 700 "${HOME}"/.gar/external.sh