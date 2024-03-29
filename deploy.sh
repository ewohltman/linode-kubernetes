#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

PROJECTCONTOUR_DIR="${SCRIPT_DIR}/projectcontour"
MONITORING_DIR="${SCRIPT_DIR}/monitoring"
OBSERVABILITY_DIR="${SCRIPT_DIR}/observability"

setup() {
  pushd . >/dev/null 2>&1 && cd "${SCRIPT_DIR}"
}

generate() {
  "${MONITORING_DIR}/generate.sh"
}

deploy() {
  "${PROJECTCONTOUR_DIR}/deploy.sh"
  sleep 1
  "${MONITORING_DIR}/deploy.sh"
  sleep 1
  "${OBSERVABILITY_DIR}/deploy.sh"
}

cleanup() {
  popd >/dev/null 2>&1
}

trap cleanup EXIT

setup
generate
deploy

echo "🚀 Deployment complete"
