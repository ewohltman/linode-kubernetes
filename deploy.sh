#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

PROJECTCONTOUR_DIR="${SCRIPT_DIR}/projectcontour"
LOGGING_DIR="${SCRIPT_DIR}/logging"
MONITORING_DIR="${SCRIPT_DIR}/monitoring"
OBSERVABILITY_DIR="${SCRIPT_DIR}/observability"

setup() {
  pushd . > /dev/null 2>&1 && cd "${SCRIPT_DIR}"
}

build() {
  "${MONITORING_DIR}/build.sh"
}

deploy() {
  "${PROJECTCONTOUR_DIR}/deploy.sh"
  sleep 1
  "${LOGGING_DIR}/deploy.sh"
  sleep 1
  "${MONITORING_DIR}/deploy.sh"
  sleep 1
  "${OBSERVABILITY_DIR}/deploy.sh"
}

cleanup() {
  popd > /dev/null 2>&1
}

trap cleanup EXIT

setup
build
deploy

echo "🚀 Deployment complete"
