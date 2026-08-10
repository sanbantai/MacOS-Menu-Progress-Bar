<p align="center">
  <img src="Resources/TheSqueezeReadmeLogo.png" width="144" alt="The Squeeze outlined circular papaya progress logo">
</p>

# The Squeeze

The Squeeze is a private, native macOS menu-bar workspace for turning time and tasks into visible progress. Start a focus timer, move work across a Kanban board, or keep quick notes—all without creating an account or sending data off your Mac.

Current release: **v0.0.2**

## Features

- Start 5, 15, 60, or 90-minute timers with one click.
- Enter a custom duration and press Return or **GO!** to start.
- Watch the papaya grinder and juice glass fill smoothly with timer progress.
- Keep progress visible in the menu bar; active work fills orange and completed work turns green.
- Move cards between persistent **Index**, **WIP**, and **Done** Kanban columns with animated drag-and-drop.
- Create, edit, reorder, and delete persistent quick notes.
- Choose which Timer, Kanban, and Notes tabs are visible.
- Confirm destructive clear actions with **Are You Sure Buddy?** before data is removed.
- Restore active timers and local workspace data after restarting the app.

## Install a release

1. Download `The-Squeeze-v0.0.2.zip` from the GitHub Releases page.
2. Unzip it and move **The Squeeze.app** to `/Applications`.
3. Open the app. It lives in the menu bar rather than showing a normal running-app Dock icon.

Release builds are ad-hoc signed. If macOS blocks the first launch, Control-click **The Squeeze.app**, choose **Open**, and confirm once.

## Build from source

Requirements: macOS 13 or newer and Xcode Command Line Tools.

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh release
open "dist/The Squeeze.app"
```

For a debug build:

```sh
swift build
```

The packaged app is an accessory app (`LSUIElement`): it is controlled from the menu bar. You can keep it in the Dock as a launcher, but its running status remains in the menu bar.

## Data and privacy

The Squeeze has no accounts, analytics, ads, tracking, third-party SDKs, or network requests. Timer state, Kanban cards, notes, and visibility settings are stored locally in macOS preferences.

See the [Privacy Policy](PRIVACY.md) for stored-data and deletion details.

## Release information

- [v0.0.2 release notes](RELEASE_NOTES.md)
- [Changelog](CHANGELOG.md)
- [Release checklist](RELEASING.md)
- [Security Policy](SECURITY.md)
- [MIT License](LICENSE)
