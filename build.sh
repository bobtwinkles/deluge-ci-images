#!/usr/bin/env bash

set -euo pipefail

DBT_TOOLCHAIN_VERSION=7
DBT_TOOLCHAIN_FILE="dbt-toolchain-${DBT_TOOLCHAIN_VERSION}-linux-x86_64.tar.gz"

wget "https://github.com/litui/dbt-toolchain/releases/download/v${DBT_TOOLCHAIN_VERSION}/"
