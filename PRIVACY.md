# Privacy Policy

Effective: August 10, 2026

The Squeeze is designed to work locally on your Mac. It has no user accounts, advertising, analytics, tracking, or third-party SDKs, and it does not transmit your data to the developer or an external service.

## Data stored on your Mac

The Squeeze stores the following information in macOS user preferences so it can restore your workspace:

- timer start, end, duration, and paused state;
- the currently active tool;
- Kanban card text, order, and column;
- quick-note text and order; and
- tool visibility preferences.

This data uses the preferences domain `com.sanbantai.thesqueeze` and remains on your Mac.

Version 0.0.2 performs a one-time local migration from the legacy `local.menuprogress.app` preferences domain. The migration copies existing workspace data into the new domain; it does not transmit or upload anything.

## Deleting data

Individual Kanban cards and notes can be deleted inside the app. The **Clear board** and **Clear notes** actions require confirmation before removing all content in their section.

To remove all current and legacy preferences, quit The Squeeze and run:

```sh
defaults delete com.sanbantai.thesqueeze
defaults delete local.menuprogress.app
```

Deleting the app does not automatically delete its macOS preferences.

## Permissions and network activity

The Squeeze does not request Calendar, Contacts, Photos, Location, Microphone, Camera, or Accessibility access. It does not make network requests.

macOS may access Apple services independently for operating-system features such as Gatekeeper or application metadata. That activity is controlled by macOS, not The Squeeze.

## Changes to this policy

If the app's data practices change, this policy will be updated before the changed version is released.

## Contact

For privacy questions, contact the maintainer through the project's GitHub repository. Do not include sensitive personal information in a public issue.
