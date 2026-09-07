# Local image used by all scripts (built by scripts/prepare.sh as gar/keri:1.1.44).
#
# The pinned gleif/keri base image plus backported keripy fixes for
# `kli mailbox debug`. See patches/mailbox-debug.py for what and why. The patch
# script fails the build if the base image no longer matches what it expects,
# so a version bump surfaces the mismatch instead of silently shipping an
# unpatched command.
FROM gleif/keri:1.1.44

COPY ./patches /patches
RUN python3 /patches/mailbox-debug.py
