FROM ghcr.io/osgeo/gdal:ubuntu-full-3.8.4

ENV LANG="C.UTF-8" LC_ALL="C.UTF-8"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y software-properties-common

RUN apt-get update && \
    apt-get -qq install -y --no-install-recommends make && \
    apt-get -qq install -y --no-install-recommends g++ && \
    apt-get -qq install -y --no-install-recommends git && \
    apt-get -qq install -y --no-install-recommends zip && \
    apt-get -qq install -y --no-install-recommends unzip && \
    apt-get -qq install -y --no-install-recommends parallel && \
    apt-get -qq install -y --no-install-recommends postgresql-client && \
    apt-get -qq install -y --no-install-recommends python3-pip && \
    apt-get -qq install -y --no-install-recommends python3-dev && \
    apt-get -qq install -y --no-install-recommends python3-psycopg2 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/ce_integratedroads
COPY requirements.txt ./

RUN pip3 install -U pip && \
    pip3 install --no-cache-dir --upgrade numpy && \
    pip3 install --no-cache-dir pyarrow && \
    pip3 install --no-cache-dir --no-binary fiona fiona && \
    pip3 install --no-cache-dir bcdata && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install