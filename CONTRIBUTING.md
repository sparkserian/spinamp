# Contributing to Spinamp

Spinamp is a desktop-focused fork of Finamp for Jellyfin music playback on macOS and Windows.

## Development Environment

Spinamp is a Flutter desktop app. Install Flutter first:

- https://docs.flutter.dev/get-started/install

Then work from the desktop targets in this repo:

- `macos/`
- `windows/`

## Current Scope

This fork is not maintaining Android or iOS.

Contributions are most useful when they improve:

- macOS behavior
- Windows behavior
- desktop UI and interaction polish
- Jellyfin playback stability
- downloads/offline support
- packaging and release automation

## Code Generation

Some dependencies rely on generated Dart files.

Run this when you change models or generated API/storage code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This applies especially to:

- Hive adapters
- `json_serializable`
- Chopper API files

If you skip generation work, you can get:

- startup failures
- settings not persisting
- JSON parsing problems

## Storage and Migrations

Spinamp uses Hive and Isar.

If you change persisted models, make sure upgrades from an existing install still work cleanly. Breaking stored data without a migration will cause app startup failures or corrupted state.

## Releases

Release docs:

- [RELEASING.md](./RELEASING.md)
- [MANUAL_RELEASE.md](./MANUAL_RELEASE.md)

## Translations

This fork has not prioritized translation workflow changes yet. If you touch localization, keep changes compatible with the existing Flutter localization setup in `lib/l10n/`.
