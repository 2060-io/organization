#!/usr/bin/env bash
set -e

MISSING=()

for VAR_NAME in "$@"; do
  VALUE="${!VAR_NAME:-}"
  if [[ -z "$VALUE" ]]; then
    MISSING+=("$VAR_NAME")
  fi
done

if (( ${#MISSING[@]} > 0 )); then
  echo "::error::Missing required variables: ${MISSING[*]}"
  exit 1
fi
