# Changelog

All notable changes to The Squeeze are documented here.

## [1.0] - 2026-08-25

### Changed

- Replaced the circular papaya application icon with the orange progress-bar logo.
- Reserved fixed layout space for the sound control and timer status so the popover never resizes between states.
- Showed an infinity symbol above the idle bar, replaced by remaining time once a timer starts.
- Prevented the Hours field from being selected automatically when the popover opens.

### Removed

- The idle “Ready” label.

## [0.0.4] - 2026-08-25

### Changed

- Replaced the animated idle menu-bar pattern with an empty, motionless progress track.
- Made timer completion fill the bar green for 10 seconds before returning it to empty.
- Simplified the popover to focus exclusively on timer controls and progress.
- Replaced snapshot-based menu-bar updates with one continuous, display-synchronized Core Animation over the timer's exact duration.
- Made clicks outside the duration fields dismiss their selection using SwiftUI focus state.
- Made empty duration fields visually blank instead of showing zeroes.
- Added a persistent bell control for turning the timer-completion sound on or off.

### Removed

- Kanban boards, quick notes, tool visibility settings, tool-switching shortcuts, and preset timer buttons.
- Papaya grinder and juice animations from the timer interface.

## [0.0.3] - 2026-08-11

### Added

- A global **Control-Shift-S** shortcut for toggling the menu-bar popover.
- **Control-1**, **Control-2**, and **Control-3** shortcuts for Kanban, Timer, and Notes.
- A collapsible keyboard-shortcut reference in Settings.
- A dedicated Kanban board progress bar with completed-card count and percentage.
- An animated papaya, white, and black idle pattern in the menu bar.

### Changed

- Reordered the tools to Kanban, Timer, and Notes.
- Gave Index, WIP, and Done stronger red, papaya, and green column treatments.
- Made menu-bar progress timer-only, using a black track with papaya fill.
- Made Kanban card and note creation Return-driven and renamed the timer prompt to “Squeeze Them Papayas.”
- Centered note drag and delete controls vertically.
- Allowed Notes to grow to the display’s usable height, then scroll by mouse or trackpad without a visible scrollbar.
- Hid Kanban scroll indicators while preserving mouse and trackpad scrolling.

### Removed

- Visible Add and Save buttons from the Kanban and Notes entry fields.
- The cursive rotating text from the menu-bar display.

## [0.0.2] - 2026-08-10

### Added

- One-click 5, 15, 60, and 90-minute timer presets.
- Custom timer start on Return.
- Animated papaya grinder, pouring juice, and smoothly filling glass.
- Animated drag-and-drop reordering for Kanban cards and quick notes.
- In-place editing for Kanban cards and notes.
- Confirmation before clearing an entire Kanban board or notes list.
- Orange active progress and green completion state in the menu bar.
- Circular papaya progress-dial application icon.
- Automatic migration from the legacy preferences domain.

### Changed

- Renamed the app from Menu Progress to The Squeeze.
- Reworked the menu-bar display with a minimal handwriting loop.
- Centered list titles and input placeholders.
- Made the popover size itself to its visible content.
- Simplified Settings and moved switches beside their tool labels.
- Increased app-wide typography for readability.

### Removed

- Checklist tool.
- Calendar integration and its permission requirements.
- Decorative Notes and Kanban header icons.

## [0.0.1] - 2026-08-10

### Added

- Initial Menu Progress release with menu-bar progress tracking.
