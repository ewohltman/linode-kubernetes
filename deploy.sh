#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

EPHEMERAL_ROLES_DIR="${SCRIPT_DIR}/ephemeral-roles"
CONTOUR_DIR="${SCRIPT_DIR}/contour"
EFK_DIR="${SCRIPT_DIR}/efk"
KUBE_PROMETHEUS_DIR="${SCRIPT_DIR}/kube-prometheus"

setup() {
  pushd . > /dev/null 2>&1 && cd "${SCRIPT_DIR}"
}

build() {
  "${KUBE_PROMETHEUS_DIR}/build.sh"
}

deploy() {
  "${EPHEMERAL_ROLES_DIR}/deploy.sh"
  "${CONTOUR_DIR}/deploy.sh"
  "${EFK_DIR}/deploy.sh"
  "${KUBE_PROMETHEUS_DIR}/deploy.sh"
}

cleanup() {
  popd > /dev/null 2>&1
}

trap cleanup EXIT

setup
build
deploy

echo "🚀 Deployment complete"
