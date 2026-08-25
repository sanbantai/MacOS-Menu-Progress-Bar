# The Squeeze v1.0

The Squeeze v1.0 is a focused, minimal menu-bar timer with continuous progress and a stable interface that never shifts between timer states.

## Highlights

- Use a streamlined timer-only interface with blank Hours, Minutes, and Seconds fields.
- Watch one continuous, display-synchronized progress animation over the timer's exact duration.
- See a completely empty, motionless bar while idle.
- See an infinity symbol above the idle bar, replaced by remaining time when a timer starts.
- See the completed bar turn green for 10 seconds before returning to empty.
- Recognize the app by its new orange progress-bar logo.
- Keep the popover at exactly the same size when the timer status or sound icon changes.
- Pause, resume, or stop an active timer.
- Click outside a duration field to dismiss its text selection.
- Open the popover with no duration field selected automatically.
- Toggle the completion sound with a persistent bell control; the muted state uses a red crossed-out bell.
- Open The Squeeze from anywhere with **Control-Shift-S**.

## Removed

- Kanban boards and their progress tracking.
- Quick notes.
- Tool visibility settings and tool-switching shortcuts.
- Preset timer buttons and papaya timer animations.

## Upgrade notes

Active and paused timers continue to restore after restarting the app. Data saved by the removed Kanban and Notes tools is no longer used, but remains in macOS preferences unless the preferences domain is deleted manually.

The Squeeze remains local-only, with no accounts, analytics, permissions, third-party SDKs, or network requests.

## Installation

1. Download `The-Squeeze-v1.0.zip` and `The-Squeeze-v1.0.zip.sha256`.
2. Verify the checksum:

   ```sh
   shasum -a 256 -c The-Squeeze-v1.0.zip.sha256
   ```

3. Unzip the archive and move **The Squeeze.app** to `/Applications`.
4. If macOS blocks the ad-hoc signed build, Control-click the app and choose **Open** once.

The Squeeze runs in the menu bar without a persistent Dock icon.
