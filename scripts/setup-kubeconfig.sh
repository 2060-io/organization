#!/usr/bin/env bash
set -e

MANIFEST="$1"
CLUSTER_NAME="$2"

CLUSTER_INDEX=$(yq e ".clusters | map(.name == \"$CLUSTER_NAME\") | index(true)" "$MANIFEST")
[ "$CLUSTER_INDEX" = "null" ] && echo "::error::Cluster not found" && exit 1

KUBECONFIG_SECRET=$(yq e ".clusters[$CLUSTER_INDEX].kubeconfigSecret" "$MANIFEST")
KUBECONFIG_VALUE="${!KUBECONFIG_SECRET:-}"
[ -z "$KUBECONFIG_VALUE" ] && echo "::error::Missing kubeconfig" && exit 1

KUBECONFIG_PATH="$RUNNER_TEMP/kubeconfig-$CLUSTER_NAME"
echo "$KUBECONFIG_VALUE" > "$KUBECONFIG_PATH"
chmod 600 "$KUBECONFIG_PATH"

export KUBECONFIG="$KUBECONFIG_PATH"
