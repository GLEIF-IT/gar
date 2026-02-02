<<<<<<< Updated upstream
FROM gleif/keri:1.1.42
=======
FROM weboftrust/keri:1.1.18
>>>>>>> Stashed changes

RUN apt-get update
RUN apt-get install -y vim

RUN useradd -ms /bin/bash gar

USER gar
WORKDIR /home/gar

COPY ./scripts scripts
