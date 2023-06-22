#!/usr/bin/env bash

set -euo pipefail

# Below hash is for linux-x86_64 release of dbt-toolchain
DBT_TOOLCHAIN_VERSION=8
DBT_TOOLCHAIN_HASH=a873607a018adb463b8136b4e6c54b4a97eb9fd1cd6656b8077f0ac54a00e1b0


DOCKER_BUILDKIT=1 \
  docker build \
    --tag 'dbt-toolchain:latest' \
    --build-arg DBT_VERSION=${DBT_TOOLCHAIN_VERSION} \
    --build-arg DBT_SHA256=${DBT_TOOLCHAIN_HASH} \
    .
