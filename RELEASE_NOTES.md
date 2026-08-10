# The Squeeze v0.0.2

The Squeeze turns timers and tasks into visible menu-bar progress, wrapped in a deliberately playful papaya-juice interface.

## Highlights

- Start a 5, 15, 60, or 90-minute timer with one click.
- Watch the grinder, pour, and glass advance smoothly with the timer.
- Organize work with animated, persistent Kanban drag-and-drop.
- Capture, edit, and reorder persistent quick notes.
- See active progress in orange and completion in green.
- Keep everything private and local—no accounts, analytics, permissions, or network requests.
- Launch from a new circular papaya progress-dial icon.

## Upgrade notes

The app is now named **The Squeeze** and uses bundle identifier `com.sanbantai.thesqueeze`. Existing data from `local.menuprogress.app` is migrated locally on first launch.

The Checklist and Calendar features are not included in v0.0.2.

## Installation

1. Download `The-Squeeze-v0.0.2.zip` and its `.sha256` file.
2. Verify the checksum:

   ```sh
   shasum -a 256 -c The-Squeeze-v0.0.2.zip.sha256
   ```

   Expected SHA-256:

   ```text
   5c1212efe14932a337f728279d014b64d5da1ec01335a7698141fb23af5c4de4
   ```

3. Unzip the archive and move **The Squeeze.app** to `/Applications`.
4. If macOS blocks the ad-hoc signed build, Control-click the app and choose **Open** once.

The Squeeze runs in the menu bar. A Dock item acts as a launcher rather than a running-app indicator.
