#!/usr/bin/env bash
set -e

echo "[DEBUG] setup-kubeconfig.sh: start"
KUBECONFIG="$1"

KUBECONFIG_VALUE="${!KUBECONFIG:-}"
[ -z "$KUBECONFIG_VALUE" ] && echo "::error::Missing kubeconfig" && exit 1

KUBECONFIG_PATH="$RUNNER_TEMP/kubeconfig"
echo "$KUBECONFIG_VALUE" > "$KUBECONFIG_PATH"
chmod 600 "$KUBECONFIG_PATH"

export KUBECONFIG="$KUBECONFIG_PATH"
