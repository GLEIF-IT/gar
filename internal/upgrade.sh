#!/bin/bash

cat <<EOF > "${HOME}"/.gar/internal.sh
# Change to the name you want to use for your local database environment.
export INT_GAR_NAME="${INT_GAR_NAME}"

# Change to the name you want for the alias for your local Internal GAR AID
export INT_GAR_ALIAS="${INT_GAR_ALIAS}"

# Change to the name you want for the alias for your group multisig Internal AID
export INT_GAR_AID_ALIAS="${INT_GAR_AID_ALIAS}"

# Change to the name you want for the alias for your group multisig Internal AID
export INT_GAR_REG_NAME="${INT_GAR_REG_NAME}"
EOF

chmod 700 "${HOME}"/.gar/internal.sh