#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

echo "🚀 Creating namespace ephemeral-roles"
kubectl apply -f "${SCRIPT_DIR}/ephemeral-roles.yaml"
