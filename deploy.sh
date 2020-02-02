#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

EPHEMERAL_ROLES_DIR="${SCRIPT_DIR}/ephemeral-roles"
KUBE_PROMETHEUS_DIR="${SCRIPT_DIR}/kube-prometheus"

setup() {
  pushd . > /dev/null 2>&1 && cd "${SCRIPT_DIR}"
}

build() {
  "${KUBE_PROMETHEUS_DIR}/build.sh"
}

deploy() {
  echo "🚀 Applying ephemeral-roles namespace yaml"
  kubectl apply -f "${EPHEMERAL_ROLES_DIR}/ephemeral-roles.yaml"

  echo "🚀 Applying kube-prometheus setup manifest yamls"
  kubectl apply -f "${KUBE_PROMETHEUS_DIR}/manifests/setup"

  echo "🚀 Waiting for kube-prometheus setup to finish"
  until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done

  echo "🚀 Applying kube-prometheus manifest yamls"
  kubectl apply -f "${KUBE_PROMETHEUS_DIR}/manifests"

  echo "🚀 Applying ephemeral-roles servicemonitor yaml"
  kubectl apply -f "${KUBE_PROMETHEUS_DIR}/servicemonitor-ephemeral-roles.yaml"
}

cleanup() {
  popd > /dev/null 2>&1
}

trap cleanup EXIT

setup
build
deploy

echo "🚀 Deployment complete"
