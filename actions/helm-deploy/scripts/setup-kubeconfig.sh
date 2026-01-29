#!/usr/bin/env bash
set -e

echo "[DEBUG] setup-kubeconfig.sh: start"
MANIFEST="$1"
CLUSTER_NAME="$2"

echo "[DEBUG] CLUSTER_NAME: '$CLUSTER_NAME'"
echo "[DEBUG] MANIFEST: '$MANIFEST'"
CLUSTER_INDEX=$(yq e ".clusters | map(.name == \"$CLUSTER_NAME\") | index(true)" "$MANIFEST")
[ "$CLUSTER_INDEX" = "null" ] && echo "::error::Cluster not found" && exit 1
echo "[DEBUG] CLUSTER_INDEX: $CLUSTER_INDEX"

KUBECONFIG_SECRET=$(yq e ".clusters[$CLUSTER_INDEX].kubeconfigSecret" "$MANIFEST")
echo "[DEBUG] KUBECONFIG_SECRET: $KUBECONFIG_SECRET"
KUBECONFIG_VALUE="${!KUBECONFIG_SECRET:-}"
[ -z "$KUBECONFIG_VALUE" ] && echo "::error::Missing kubeconfig" && exit 1

KUBECONFIG_PATH="$RUNNER_TEMP/kubeconfig"
echo "$KUBECONFIG_VALUE" > "$KUBECONFIG_PATH"
chmod 600 "$KUBECONFIG_PATH"

export KUBECONFIG="$KUBECONFIG_PATH"
