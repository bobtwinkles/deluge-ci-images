# syntax=docker/dockerfile:1-labs
# Download and unpack the toolchain on the build host architecture
FROM --platform=$BUILDPLATFORM ubuntu:latest as toolchain-unpacker
ARG BUILDPLATFORM
ARG DBT_VERSION=7
ARG DBT_TOOLCHAIN_SHA_x86_64=ee26a2e2cc432c772bc2653baa6edd7c0b8bfa86c9f7041fa5395293dce74e5f
ARG DBT_TOOLCHAIN_SHA_arm64=a2cf55fcdd6da31e8d961db7e8dabbc8d6dcdc5cacd2b09da4fc45bd4b06cd50
ARG TOOLCHAIN_URL=https://github.com/litui/dbt-toolchain/releases/download

# Install tools required to unpack the toolchain archive
RUN apt-get update && apt-get install -y curl parallel

# Local development: use locally downloaded toolchain files
# COPY ./dbt-toolchain-7-linux-arm64.tar.gz /dbt/toolchain/
# COPY ./dbt-toolchain-7-linux-x86_64.tar.gz /dbt/toolchain/

# Load the toolchain
RUN <<LOAD_TOOLCHAIN bash
  set -ex
  mkdir -p /dbt/toolchain
  cd /dbt/toolchain
  targets="x86_64 arm64"
  for target_arch in \$targets; do
    DBT_TOOLCHAIN_TAR=dbt-toolchain-${DBT_VERSION}-linux-\${target_arch}.tar.gz

    # For local development (see COPY commands above) don't redownload
    # toolchains if they're already present
    if [ ! -e "\${DBT_TOOLCHAIN_TAR}" ]; then
      curl -LO ${TOOLCHAIN_URL}/v${DBT_VERSION}/\${DBT_TOOLCHAIN_TAR}
      sha256sum \${DBT_TOOLCHAIN_TAR} | grep "$DBT_TOOLCHAIN_SHA_\$target_arch"
    fi

    # Untar the toolchain and delete the tar file to reduce layer size
    tar xf \${DBT_TOOLCHAIN_TAR} 2> >(grep -v "tar: Ignoring unknown extended header keyword")
    rm \${DBT_TOOLCHAIN_TAR}
    # Delete OSX files that shouldn't be there and cause problems for Python
    find /dbt/toolchain/linux-\$target_arch/ -type f -name '.*' -delete
    # Make Python R+W by the build user
    find /dbt/toolchain/linux-\$target_arch/python | \
      parallel chown 1000:1000 {} \; chmod a+rw {}
  done
  # kinda stupid hack: move linux-x86_64 to linux-amd64 so we can do a COPY
  # --from below using the Docker TARGETARCH. We then move it back to the right position
  mv /dbt/toolchain/linux-x86_64/ /dbt/toolchain/linux-amd64
  ls /dbt/toolchain
LOAD_TOOLCHAIN

# Configure user
RUN useradd -ms /bin/bash nonroot

# The build container
FROM ubuntu:latest AS builder
ARG TARGETARCH

# Install tools required by DBT
RUN apt-get update && apt-get install -y git

# Configure user
RUN useradd -ms /bin/bash nonroot

# Copy DBT from the unpack container
COPY --from=toolchain-unpacker /dbt/toolchain/linux-$TARGETARCH/ /dbt/toolchain/linux-$TARGETARCH/
RUN if [ "$TARGETARCH" = "amd64" ]; then mv /dbt/toolchain/linux-amd64 /dbt/toolchain/linux-x86_64; fi
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
FROM ubuntu:latest as final
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
