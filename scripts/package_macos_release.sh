#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_bin="${FLUTTER_BIN:-}"

if [[ -z "$flutter_bin" ]]; then
  if [[ -x "$repo_root/flutterw" ]]; then
    flutter_bin="$repo_root/flutterw"
  else
    flutter_bin="flutter"
  fi
fi

artifact_version="$("$repo_root/scripts/release_version.sh" artifact)"
artifact_name="spinamp-macos-${artifact_version}.dmg"
dist_dir="$repo_root/dist"
artifact_path="$dist_dir/$artifact_name"
stage_dir="$repo_root/build/release-stage/macos"
app_path="$repo_root/build/macos/Build/Products/Release/Spinamp.app"

mkdir -p "$dist_dir"
find "$dist_dir" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -exec rm -rf {} +

"$flutter_bin" build macos --release

mkdir -p "$stage_dir"
find "$stage_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
ditto "$app_path" "$stage_dir/Spinamp.app"
ln -s /Applications "$stage_dir/Applications"

hdiutil create \
  -volname Spinamp \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$artifact_path"

printf '%s\n' "$artifact_path"
