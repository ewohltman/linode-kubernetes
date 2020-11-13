#!/usr/bin/env bash
# This script uses arg $1 (name of *.jsonnet file to use) to generate the
# manifests/*.yaml files. If not provided, default to config.jsonnet.

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

CONFIG_FILE="config.jsonnet"

setup() {
  pushd . >/dev/null 2>&1 && cd "${SCRIPT_DIR}"

  echo "🚀 Cleaning kube-prometheus build environment"
  rm -rf vendor
  rm -rf manifests
  mkdir -p manifests/setup

  echo "🚀 Getting required kube-prometheus tools"
  go get -u github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
  go get -u github.com/google/go-jsonnet/cmd/jsonnet
  go get -u github.com/brancz/gojsontoyaml

  echo "🚀 Syncing with upstream kube-prometheus"
  jb install github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus@release-0.6 2>/dev/null
  jb update 2>/dev/null
}

build() {
  echo "🚀 Config file for kube-prometheus: ${CONFIG_FILE}"

  echo "🚀 Generating kube-prometheus yaml files"
  jsonnet -J vendor -m manifests "${CONFIG_FILE}" | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml; rm -f {}' -- {}

  find manifests -type f ! -name '*.yaml' -delete

  cp custom/0monitoring-namespace.yaml manifests/setup
  cp custom/grafana-httpproxy.yaml manifests
  cp custom/servicemonitor-ephemeral-roles.yaml manifests
}

cleanup() {
  popd >/dev/null 2>&1
}

trap cleanup EXIT

setup
build

echo "🚀 Generating kube-prometheus yaml files complete"
