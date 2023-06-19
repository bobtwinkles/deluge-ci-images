#!/usr/bin/env bash

set -euo pipefail

DBT_TOOLCHAIN_VERSION=7
DBT_TOOLCHAIN_HASH=ee26a2e2cc432c772bc2653baa6edd7c0b8bfa86c9f7041fa5395293dce74e5f

DOCKER_BUILDKIT=1 \
  docker build \
    --tag 'dbt-toolchain:latest' \
    --build-arg DBT_VERSION=${DBT_TOOLCHAIN_VERSION} \
    --build-arg DBT_SHA256=${DBT_TOOLCHAIN_HASH} \
    .
