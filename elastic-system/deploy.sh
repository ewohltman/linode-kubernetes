#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

echo "🚀 Deploying ECK Operator"
kubectl apply -f "${SCRIPT_DIR}/all-in-one.yaml"

echo "🚀 Deploying Elasticsearch Cluster"
kubectl apply -f "${SCRIPT_DIR}/elasticsearch.yaml"

echo "🚀 Deploying Kibana"
kubectl apply -f "${SCRIPT_DIR}/kibana.yaml"

echo "🚀 Deploying Grafana Contour HTTPProxy"
kubectl apply -f "${SCRIPT_DIR}/kibana-httpproxy.yaml"
