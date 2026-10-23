# syntax=docker/dockerfile:1
# Debian suite for the python base image, passed per region by the Makefile
# (UK_DEBIAN_SUITE / AU_DEBIAN_SUITE) and part of the published image tag.
# trixie is the current stable; bookworm still builds. Package lists below must
# work on both: `file` pulls libmagic1 on bookworm and libmagic1t64 on trixie.
ARG DEBIAN_SUITE=trixie
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_SUITE}

ARG PLONE_VERSION

# Database driver pins installed alongside Plone, passed per region by the
# Makefile (UK_EXTRA_PACKAGES / AU_EXTRA_PACKAGES). relstorage 3.5.0 does not
# compile with GCC 13+ (trixie has 14); 4.x builds and ships cp312 wheels.
ARG EXTRA_PACKAGES="relstorage==4.1.1 psycopg2==2.9.10 python-ldap==3.4.4 ZEO"
ENV EXTRA_PACKAGES=${EXTRA_PACKAGES}


LABEL maintainer="Plone Community <dev@plone.org>" \
      org.label-schema.name="server-builder" \
      org.label-schema.description="Plone $PLONE_VERSION builder image with Python $PYTHON_VERSION" \
      org.label-schema.vendor="Plone Foundation"


# Script used for pre-compilation of po files
COPY /helpers/compile_mo.py /compile_mo.py

# Install Plone
#  - Install build dependencies
#  - Download constraints.txt file to /app folder
#  - Install Plone using pip
#  - Create /data folder
#  - Pre-compile po files in the /app/lib folder
#  - Remove .pyc and .pyo files
#
RUN <<EOT
    set -e
    apt-get update
    apt-get -y upgrade
    buildDeps="build-essential busybox ca-certificates curl git gosu libbz2-dev libffi-dev libjpeg62-turbo-dev file libldap2-dev libopenjp2-7-dev libpq-dev libsasl2-dev libssl-dev libtiff-dev libxml2-dev libxslt1-dev wget zlib1g-dev"
    apt-get install -y --no-install-recommends $buildDeps
    busybox --install -s
    python -m venv /app
    curl -L -o /app/constraints.txt https://dist.plone.org/release/$PLONE_VERSION/constraints.txt
    /app/bin/pip install -U pip wheel setuptools -c /app/constraints.txt
    /app/bin/pip install Plone ${EXTRA_PACKAGES} -c /app/constraints.txt
    bash -c 'mkdir -p /data/{filestorage,blobstorage,cache,logs}'
    /app/bin/python /compile_mo.py
    find /app \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' +
EOT

# Copy default structure for a Plone Project
COPY /skeleton/etc /app/etc
COPY /skeleton/scripts /app/scripts
COPY /skeleton/docker-entrypoint.sh /app/
COPY /skeleton/inituser /app/
