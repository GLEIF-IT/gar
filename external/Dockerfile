# Local image used by all scripts (built by scripts/prepare.sh as gar/keri:1.1.44).
#
# The pinned gleif/keri base image plus backported keripy fixes. Each script in
# patches/ says what it changes and why, and fails the build if the base image
# no longer matches what it expects, so a version bump surfaces the mismatch
# instead of silently shipping unpatched code.
FROM gleif/keri:1.1.44

COPY ./patches /patches
RUN python3 /patches/mailbox-debug.py
RUN python3 /patches/exn-missing-rp.py
RUN python3 /patches/delegate-confirm-summary.py
