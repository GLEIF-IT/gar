
##################################################################
##                                                              ##
##        Setup local environment as an Internal GAR            ##
##                                                              ##
##################################################################

# Pull container required to run all KERI/ACDC commands
docker pull gleif/keri:1.1.44

# Build the local image used by all scripts: the pulled image plus small
# backported kli fixes (see Dockerfile and patches/). Must run from this directory.
docker build -t gar/keri:1.1.44 .

# Create local directory for datastore, keystore and configuration
mkdir -p "${HOME}"/.gar/cf

# Protect directory from others
chmod 700 "${HOME}"/.gar

# Copy AID configuration information for loading
cp -R scripts/keri/cf/ ~/.gar/cf

