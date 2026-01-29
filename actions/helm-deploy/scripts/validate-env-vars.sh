#!/usr/bin/env bash
set -e

echo "[DEBUG] Arguments received: $@"
echo "[DEBUG] Number of arguments: $#"

MISSING=()
for VAR_NAME in "$@"; do
  echo "[DEBUG] Checking variable: $VAR_NAME"
  VALUE="${!VAR_NAME:-}"
  echo "[DEBUG] Value of $VAR_NAME: '$VALUE'"
  
  if [[ -z "$VALUE" ]]; then
    MISSING+=("$VAR_NAME")
  fi
done

if (( ${#MISSING[@]} > 0 )); then
  echo "::error::Missing required variables: ${MISSING[*]}"
  exit 1
fi
