#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

echo "🚀 Creating namespace logging"
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

echo "🚀 Deploying Elasticsearch"
kubectl apply -f "${SCRIPT_DIR}/elasticsearch.yaml"
kubectl -n logging rollout status sts/es-cluster

echo "🚀 Deploying Kibana"
kubectl apply -f "${SCRIPT_DIR}/kibana.yaml"
kubectl -n logging rollout status deployment/kibana

echo "🚀 Deploying Fluentd"
kubectl apply -f "${SCRIPT_DIR}/fluentd.yaml"
kubectl -n logging rollout status daemonset/fluentd

echo "🚀 Deploying Grafana Contour HTTPProxy"
kubectl apply -f "${SCRIPT_DIR}/kibana-httpproxy.yaml"
