FROM ghcr.io/osgeo/gdal:ubuntu-full-3.10.0

ENV LANG="C.UTF-8" LC_ALL="C.UTF-8"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y software-properties-common

RUN apt-get update && \
    apt-get -qq install -y --no-install-recommends g++ && \
    apt-get -qq install -y --no-install-recommends git && \
    apt-get -qq install -y --no-install-recommends zip && \
    apt-get -qq install -y --no-install-recommends unzip && \
    apt-get -qq install -y --no-install-recommends jq && \
    apt-get -qq install -y --no-install-recommends parallel && \
    apt-get -qq install -y --no-install-recommends postgresql-client && \
    apt-get -qq install -y --no-install-recommends python3-pip && \
    apt-get -qq install -y --no-install-recommends python3-dev && \
    apt-get -qq install -y --no-install-recommends python3-venv && \
    apt-get -qq install -y --no-install-recommends python3-psycopg2 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/ce_integratedroads

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/python -m pip install -U pip && \
    /opt/venv/bin/python -m pip install --no-cache-dir --upgrade numpy && \
    /opt/venv/bin/python -m pip install --no-cache-dir pyarrow && \
    /opt/venv/bin/python -m pip install --no-cache-dir bcdata==0.15.0 && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

ENV PATH="/opt/venv/bin:$PATH"