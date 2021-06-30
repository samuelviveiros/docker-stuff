FROM ubuntu:20.04

RUN apt update && \
    apt install python3.8 python3-venv -y && \
    apt install inetutils-ping -y
    #apt dist-upgrade -y && \
    #apt autoremove && \
    #apt autoclean

VOLUME /app

WORKDIR /app

