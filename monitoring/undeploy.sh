#!/usr/bin/env bash

# set -e
# set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

echo "🚀 Undeploying kube-prometheus manifest yamls"
kubectl delete -f "${SCRIPT_DIR}/manifests" 2>/dev/null

echo "🚀 Undeploying kube-prometheus setup manifest yamls"
kubectl delete -f "${SCRIPT_DIR}/manifests/setup" 2>/dev/null
