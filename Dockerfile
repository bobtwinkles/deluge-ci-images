# syntax=docker/dockerfile:1-labs
FROM ubuntu:latest AS builder
ARG DBT_VERSION
ARG DBT_SHA256

# Install tools required by DBT
RUN apt-get update && apt-get install -y git

# Configure user
RUN useradd -ms /bin/bash nonroot

# Load the toolchain
ADD --checksum=sha256:$DBT_SHA256 \
  https://github.com/litui/dbt-toolchain/releases/download/v$DBT_VERSION/dbt-toolchain-$DBT_VERSION-linux-x86_64.tar.gz \
  /dbt/toolchain/
RUN cd /dbt/toolchain \
  && tar -xvf dbt-toolchain-$DBT_VERSION-linux-x86_64.tar.gz \
  && rm dbt-toolchain-$DBT_VERSION-linux-x86_64.tar.gz
RUN find /dbt/toolchain | grep -e '\/[.][^\/]*$' | sed -e 's/\(.*\)/rm \"\1\"/' | /usr/bin/env bash
ENV DBT_TOOLCHAIN_PATH=/dbt

# Smoke run, which both checks that the toolchain is working and installs the
# wheels for us so we don't need to ship those in the final image.
ADD --keep-git-dir=true https://github.com/SynthstromAudible/DelugeFirmware.git#litui/xmlbuild /build
RUN cd /build && ./dbt
RUN rm -rf /dbt/toolchain/linux-x86_64/python/wheel/*

#
# Build the final image, based on distroless
#
FROM ubuntu:latest

# Make sure we have git, as it's needed at runtime
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Insert the DBT itself
COPY --from=builder /dbt /dbt
RUN useradd -ms /bin/bash nonroot
ENV DBT_TOOLCHAIN_PATH=/dbt
USER nonroot

WORKDIR /src/
ENTRYPOINT ["/src/dbt"]
