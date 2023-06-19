# syntax=docker/dockerfile:1-labs
# The build container
FROM ubuntu:latest AS builder
ARG TARGETARCH
ARG DBT_VERSION=7
ARG DBT_TOOLCHAIN_SHA_x86_64=ee26a2e2cc432c772bc2653baa6edd7c0b8bfa86c9f7041fa5395293dce74e5f
ARG DBT_TOOLCHAIN_SHA_arm64=a2cf55fcdd6da31e8d961db7e8dabbc8d6dcdc5cacd2b09da4fc45bd4b06cd50
ARG TOOLCHAIN_URL=https://github.com/litui/dbt-toolchain/releases/download

# Install tools required by DBT
RUN apt-get update && apt-get install -y git curl parallel

# Configure user
RUN useradd -ms /bin/bash nonroot

# Load the toolchain
RUN <<LOAD_TOOLCHAIN bash
  set -ex
  mkdir -p /dbt/toolchain
  cd /dbt/toolchain
  case "$TARGETARCH" in
    amd64)
      DBT_TOOLCHAIN_TAR=dbt-toolchain-${DBT_VERSION}-linux-x86_64.tar.gz
      DBT_ARCH=x86_64
      curl -LO ${TOOLCHAIN_URL}/v${DBT_VERSION}/\${DBT_TOOLCHAIN_TAR}
      sha256sum \${DBT_TOOLCHAIN_TAR} | grep "$DBT_TOOLCHAIN_SHA_x86_64"
      ;;
    arm64)
      DBT_TOOLCHAIN_TAR=dbt-toolchain-${DBT_VERSION}-linux-arm64.tar.gz
      DBT_ARCH=arm64
      curl -LO ${TOOLCHAIN_URL}/v${DBT_VERSION}/\${DBT_TOOLCHAIN_TAR}
      sha256sum \${DBT_TOOLCHAIN_TAR} | grep "$DBT_TOOLCHAIN_SHA_arm64"
      ;;
    *)
      echo "Unsupported TARGETARCH" $TARGETARCH
      exit 1
      ;;
  esac
  tar xf \${DBT_TOOLCHAIN_TAR} 2> >(grep -v "tar: Ignoring unknown extended header keyword")
  rm \${DBT_TOOLCHAIN_TAR}
  find /dbt/toolchain | grep -e '\/[.][^\/]*$' | parallel rm
  find ${DBT_TOOLCHAIN_PATH}/toolchain/linux-\$DBT_ARCH/python | \
    parallel bash -c "chown 1000:1000 {} && chmod a+rw {}"
LOAD_TOOLCHAIN
ENV DBT_TOOLCHAIN_PATH=/dbt

# Smoke run, which both checks that the toolchain is working and installs the
# wheels for us so we don't need to ship those in the final image.
ADD --keep-git-dir=true https://github.com/SynthstromAudible/DelugeFirmware.git#community /build
RUN <<SMOKE_BUILD bash
  set -ex
  cd /build
  # We only actually build on amd64 because running the compiler under
  # emulation is extremely slow.
  case "$TARGETARCH" in
    amd64) ./dbt --e2_target=dbt-build-release-oled; ;;
    arm64) ./dbt --help ;;
    *)
      echo "Unsupported TARGETARCH" $TARGETARCH
      exit 1
      ;;
  esac
SMOKE_BUILD
RUN rm -rf /dbt/toolchain/linux-$TARGETARCH/python/wheel/*

#
# Build the final image, based on distroless
#
FROM ubuntu:latest
ARG TARGETARCH

# Make sure we have git, as it's needed at runtime
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Insert the DBT itself
COPY --from=builder /dbt /dbt
RUN useradd -ms /bin/bash nonroot
ENV DBT_TOOLCHAIN_PATH=/dbt
USER nonroot

WORKDIR /src/
ENTRYPOINT ["/src/dbt"]
