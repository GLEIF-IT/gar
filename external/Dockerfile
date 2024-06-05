FROM weboftrust/keri:1.1.16

RUN apt-get update
RUN apt-get install -y vim

RUN useradd -ms /bin/bash gar

USER gar
WORKDIR /home/gar

COPY ./scripts scripts
