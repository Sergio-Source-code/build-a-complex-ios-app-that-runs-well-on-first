# Daylight

An offline-first SwiftUI planner for iOS 17+. No account, API keys, permissions, packages, or network access required.

## Features

- Today dashboard with priorities, completion progress, daily habits, and focus shortcuts.
- Task creation, editing, deletion, completion, notes, dates, areas, priorities, and time estimates.
- Weekly planner, date selection, all-task search, and area/completion filters.
- Custom daily habits with check-ins, current streaks, and weekly history.
- 15/25/45/60-minute focus sessions with pause/resume and task association. The persisted deadline survives backgrounding and relaunch; elapsed sessions are recorded once when the app returns. No background notification is scheduled.
- Weekly task charts, focus totals, and area breakdowns.
- Settings with confirmed empty/example resets and privacy information.

## First launch and storage

The initial launch creates clearly labeled example tasks and habits. No historical focus sessions are fabricated. Changes are saved atomically to `Application Support/daylight-data.json`; subsequent launches restore that file without reseeding. Unreadable files are preserved rather than silently replaced. Data is local, not synced. Settings can clear all examples for a fresh start.

## Build and test

`project.yml` defines the XcodeGen project. Generate it using XcodeGen on macOS, then open the generated project in Xcode and select the App scheme and an iOS 17+ simulator. Run the App scheme to launch, or Test to run AppTests. Keep the configured product bundle identifier unchanged; the build pipeline manages signing. `icon.json` is rendered into the app icon by the build pipeline.

Tests cover first-launch seeding, task/habit persistence, pause restoration, exactly-once focus completion after relaunch, corrupted-file preservation, and habit streaks.

The Linux development sandbox can validate Swift syntax but cannot compile SwiftUI or execute iOS XCTest. An Xcode build and simulator run are still required for platform validation.
