# Menu Progress

A small native macOS menu-bar app that keeps the progress of a timer or calendar event visible at a glance.

## Features

- Start 5, 15, 60, or 90-minute timers, or enter a custom duration in hours, minutes, and seconds.
- See a continuous progress bar and the “THERE AIN'T NO GRAVE” label directly in the macOS menu bar.
- Pause, resume, and stop manual timers.
- Hear the Glass system sound when a timer, checklist, or Kanban board reaches completion.
- Track and edit tasks in a persistent drag-and-drop Index, WIP, and Done Kanban board.
- Edit checklist tasks and persistent quick notes in place.
- Hide or show Timer, Checklist, Kanban, and Notes from the bottom Settings tab.
- View today's remaining Apple Calendar events and track any event's progress.
- Works with Google Calendar through the Google account already connected to macOS.
- Restores the active timer after the app restarts.

## Build and run

Requirements: macOS 13 or newer and Xcode Command Line Tools.

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open "dist/Menu Progress.app"
```

On first use, click **Connect Calendar** and allow calendar access. To expose a Google calendar, open **System Settings → Internet Accounts → your Google account** and enable **Calendars**. The events should also be visible in Apple's Calendar app.

Because this local build is ad-hoc signed, macOS may ask for Calendar permission again after rebuilding it. For regular personal use, move the finished app to `/Applications` before granting permission.

## Development

Run a debug build with:

```sh
swift build
```

The packaged app is intentionally an accessory app: it has no Dock icon and is controlled entirely from the menu bar.

## Project policies

- [MIT License](LICENSE)
- [Privacy Policy](PRIVACY.md)
- [Security Policy](SECURITY.md)
