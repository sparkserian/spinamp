#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$repo_root/.env.local"

if [[ ! -f "$env_file" ]]; then
  echo ".env.local not found at $env_file" >&2
  exit 1
fi

set -a
source "$env_file"
set +a

asset_path="$("$repo_root/scripts/package_macos_release.sh" | tail -n 1)"
python3 "$repo_root/scripts/upload_github_release_asset.py" "$asset_path" "${1:-}"
