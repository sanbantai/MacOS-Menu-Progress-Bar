# Privacy Policy

Effective: August 10, 2026

Menu Progress is designed to work locally on your Mac. It does not include user accounts, advertising, analytics, tracking, or third-party SDKs, and it does not transmit your data to the developer or any external server.

## Data stored on your Mac

Menu Progress stores the following information locally in macOS user preferences so that it can restore your workspace:

- timer start, end, and paused state;
- checklist items and their completion state;
- Kanban cards and their columns;
- quick notes; and
- tool visibility preferences.

This information stays on your Mac. You can delete checklist items, Kanban cards, and notes from within the app. You can remove all saved Menu Progress preferences by quitting the app and running:

```sh
defaults delete local.menuprogress.app
```

## Calendar access

Calendar access is optional. If you grant permission, Menu Progress uses Apple's EventKit framework to read upcoming timed events from calendars already configured on your Mac.

The list of upcoming events is held in memory and is not uploaded. When you choose to track an event, its title, start time, and end time are stored locally as the active progress session so that it can be restored after the app restarts.

You can revoke Calendar access at any time in **System Settings → Privacy & Security → Calendars**.

## Network activity

Menu Progress does not make network requests. Calendar providers such as iCloud or Google may synchronize through macOS independently of Menu Progress under their own privacy policies.

## Changes to this policy

If the app's data practices change, this policy will be updated with a new effective date before those changes are released.

## Contact

For privacy questions, contact the maintainer through the project's GitHub repository. Do not include sensitive personal information in a public issue.
