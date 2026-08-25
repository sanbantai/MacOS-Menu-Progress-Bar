<p align="center">
  <img src="Resources/TheSqueezeReadmeLogo.png" width="144" alt="The Squeeze outlined circular papaya progress logo">
</p>

# The Squeeze

The Squeeze is a private, native macOS menu-bar focus timer that turns time into visible progress without creating an account or sending data off your Mac.

Current release: **v0.0.4**.

## Features

- Toggle The Squeeze from anywhere with **Control-Shift-S**.
- Enter a custom duration and press Return or **Start Timer**.
- Pause, resume, or stop an active timer.
- See an empty, motionless menu-bar track while idle.
- Watch the track fill as the timer advances.
- See the completed bar turn green for 10 seconds, then return to empty.
- Toggle the timer-completion sound from the bell control.
- Restore an active or paused timer after restarting the app.

## Install a release

1. Download `The-Squeeze-v0.0.4.zip` from the GitHub Releases page.
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

The Squeeze has no accounts, analytics, ads, tracking, third-party SDKs, or network requests. Active timer state is stored locally in macOS preferences.

See the [Privacy Policy](PRIVACY.md) for stored-data and deletion details.

## Release information

- [v0.0.4 release notes](RELEASE_NOTES.md)
- [Changelog](CHANGELOG.md)
- [Release checklist](RELEASING.md)
- [Security Policy](SECURITY.md)
- [MIT License](LICENSE)
