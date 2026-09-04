FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        openssh-client \
        postgresql-client \
        python3 \
        python3-pip \
        python3-venv \
        python3.12-venv \
        sudo \
        zstd \
    && mkdir -p --mode=0755 /usr/share/keyrings \
    && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
         -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
         -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends tailscale \
    && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu \
    && rm -rf /var/lib/apt/lists/*

USER ubuntu
