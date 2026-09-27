#!/usr/bin/env bash
set -euo pipefail

kit_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sandbox="${1:-agy-current}"

if [[ $# -gt 0 ]]; then
  shift
fi

exec sbx run "$kit_dir" --name "$sandbox" "$@"
