
##################################################################
##                                                              ##
##        Setup local environment as an External GAR            ##
##                                                              ##
##################################################################

# Pull container required to run all KERI/ACDC commands
docker pull weboftrust/keri:1.1.11-arm64

# Create local directory for datastore, keystore and configuration
mkdir -p "${HOME}"/.gar/cf

# Protect directory from others
chmod 700 "${HOME}"/.gar

# Copy AID configuration information for loading
cp -R scripts/keri/cf/ ~/.gar/cf

