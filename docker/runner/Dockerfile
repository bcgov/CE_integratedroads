FROM ghcr.io/osgeo/gdal:ubuntu-full-3.13.1

RUN apt-get update && apt-get --assume-yes upgrade \
    && apt-get -qq install -y --no-install-recommends postgresql-common \
    && apt-get -qq install -y --no-install-recommends yes \
    && apt-get -qq install -y --no-install-recommends gnupg \
    && yes '' | sh /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh \
    && apt-get -qq install -y --no-install-recommends postgresql-client-16 \
    && apt-get -qq install -y --no-install-recommends git \
    && apt-get -qq install -y --no-install-recommends zip \
    && apt-get -qq install -y --no-install-recommends unzip \
    && apt-get -qq install -y --no-install-recommends jq \
    && apt-get -qq install -y --no-install-recommends curl \
    && apt-get -qq install -y --no-install-recommends parallel \
    && apt-get -qq install -y --no-install-recommends python3-pip \
    && apt-get -qq install -y --no-install-recommends python3-venv \
    && apt-get -qq install -y --no-install-recommends pipx \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(uname -m) \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}-2.22.21.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

WORKDIR /home/ce_integratedroads

RUN pipx install bcdata==0.16.0
ENV PATH="/root/.local/bin:$PATH"