# Manual Release Commands

These commands assume you are inside the project root:

```bash
cd /Users/williamawuku/Downloads/my-dev-projects/spinamp
```

## 1. Bump the release number

Set the new app version and build number:

```bash
export RELEASE_VERSION=1.0.0
export RELEASE_BUILD=110
```

Update `pubspec.yaml`:

```bash
python3 - <<'PY'
from pathlib import Path
import os
import re

release_version = os.environ["RELEASE_VERSION"]
release_build = os.environ["RELEASE_BUILD"]
path = Path("pubspec.yaml")
text = path.read_text()

text = re.sub(
    r"^version:\s*.+$",
    f"version: {release_version}+{release_build}",
    text,
    count=1,
    flags=re.MULTILINE,
)
text = re.sub(
    r"^  msix_version:\s*.+$",
    f"  msix_version: {release_version}.{release_build}",
    text,
    count=1,
    flags=re.MULTILINE,
)

path.write_text(text)
PY
```

Check the release values:

```bash
./scripts/release_version.sh raw
./scripts/release_version.sh tag
```

## 2. Commit and push the release code

```bash
git add pubspec.yaml
git commit -m "Release ${RELEASE_VERSION}+${RELEASE_BUILD}"
git push origin main
```

## 3. Build and publish the macOS DMG

If `flutter` is already on your `PATH`, run:

```bash
./scripts/publish_macos_release.sh
```

If you need to point at a specific Flutter binary, run:

```bash
export FLUTTER_BIN=/absolute/path/to/flutter
./scripts/publish_macos_release.sh
```

This will:
- build the macOS release app
- create the DMG in `dist/`
- create or update the GitHub release
- upload the DMG asset

## 4. Trigger the Windows installer build on GitHub Actions

Load your GitHub release credentials:

```bash
set -a
source .env.local
set +a
```

Dispatch the Windows release workflow against the current release tag:

```bash
export RELEASE_TAG="$(./scripts/release_version.sh tag)"
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$GH_RELEASE_OWNER/$GH_RELEASE_REPO/actions/workflows/desktop-release.yml/dispatches" \
  -d "{\"ref\":\"main\",\"inputs\":{\"release_tag\":\"${RELEASE_TAG}\"}}"
```

## 5. Open the release page

```bash
echo "https://github.com/$GH_RELEASE_OWNER/$GH_RELEASE_REPO/releases/tag/$(./scripts/release_version.sh tag)"
```

Expected release assets:
- `spinamp-macos-v<version>.dmg`
- `spinamp-windows-installer-v<version>.exe`
