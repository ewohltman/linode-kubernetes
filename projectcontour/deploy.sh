#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

echo "🚀 Deploying Contour"
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml

echo "🚀 Deploying ephemeral-roles.net HTTPProxy"
kubectl apply -f "${SCRIPT_DIR}/httpproxy.yaml"
