#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_line="$(sed -n 's/^version:[[:space:]]*//p' "$repo_root/pubspec.yaml" | head -n 1)"

if [[ -z "$version_line" ]]; then
  echo "Unable to determine version from pubspec.yaml" >&2
  exit 1
fi

build_name="${version_line%%+*}"
if [[ "$version_line" == *"+"* ]]; then
  build_number="${version_line##*+}"
else
  build_number=""
fi

case "${1:-raw}" in
  raw)
    printf '%s\n' "$version_line"
    ;;
  tag)
    if [[ -n "$build_number" ]]; then
      printf 'v%s-%s\n' "$build_name" "$build_number"
    else
      printf 'v%s\n' "$build_name"
    fi
    ;;
  build-name)
    printf '%s\n' "$build_name"
    ;;
  build-number)
    printf '%s\n' "$build_number"
    ;;
  artifact)
    printf 'v%s\n' "$version_line"
    ;;
  *)
    echo "Unknown mode: ${1}" >&2
    exit 1
    ;;
esac
