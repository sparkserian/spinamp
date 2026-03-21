# Releasing Spinamp

## Local macOS release

1. Fill in `.env.local` with:
   - `GH_RELEASE_OWNER`
   - `GH_RELEASE_REPO`
   - `GH_TOKEN`
2. Run:

```bash
./scripts/publish_macos_release.sh
```

This will:
- build the macOS app
- package `dist/spinamp-macos-v<version>.dmg`
- create or update the GitHub release for the current version tag
- upload the DMG asset

## Windows release

1. Push the code to the `spinamp` GitHub repository.
2. Push a tag matching the release tag format, for example:

```bash
git tag v0.9.7-107
git push origin v0.9.7-107
```

The `Desktop Artifacts` GitHub Actions workflow will:
- build the Windows release bundle
- package `dist/spinamp-windows-v<version>.zip`
- create the GitHub release if it does not already exist
- upload the Windows asset to that release
