FROM gleif/keri:1.1.44

# Backport upstream keripy fixes for `kli mailbox debug` onto the pinned base
# image. See patches/mailbox-debug.py for what and why. Runs as root, before
# the user switch below, because /keripy is root owned. The patch script fails
# the build if the base image no longer matches what it expects.
COPY ./patches /patches
RUN python3 /patches/mailbox-debug.py

RUN apt-get update
RUN apt-get install -y vim

RUN useradd -ms /bin/bash gar

USER gar
WORKDIR /home/gar

COPY ./scripts scripts
