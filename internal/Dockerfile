FROM weboftrust/keri:1.1.11-arm64

RUN apt-get update
RUN apt-get install -y vim

RUN useradd -ms /bin/bash gar

USER gar
WORKDIR /home/gar

COPY ./scripts scripts
