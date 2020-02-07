#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

EPHEMERAL_ROLES_DIR="${SCRIPT_DIR}/ephemeral-roles"
PROJECTCONTOUR_DIR="${SCRIPT_DIR}/projectcontour"
LOGGING_DIR="${SCRIPT_DIR}/logging"
MONITORING_DIR="${SCRIPT_DIR}/monitoring"

setup() {
  pushd . > /dev/null 2>&1 && cd "${SCRIPT_DIR}"
}

build() {
  "${MONITORING_DIR}/build.sh"
}

deploy() {
  "${EPHEMERAL_ROLES_DIR}/deploy.sh"
  "${PROJECTCONTOUR_DIR}/deploy.sh"
  "${LOGGING_DIR}/deploy.sh"
  "${MONITORING_DIR}/deploy.sh"
}

cleanup() {
  popd > /dev/null 2>&1
}

trap cleanup EXIT

setup
build
deploy

echo "🚀 Deployment complete"
