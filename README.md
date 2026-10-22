# Toki

Toki (時, Japanese for "time") is an iPhone app for working hours, overtime and
vacation days. It does what a classic time tracker does, plus two things most of
them cannot:

- **Vacation credits** — whole extra vacation days for single days, e.g. for a
  weekend assignment or a travel day. The day then counts as no overtime.
- **Automatic entries by location** — arriving at and leaving the office are
  recorded in the background (first arrival = start, last departure = end,
  rounded to 5 minutes, stays under one hour ignored, odd days flagged).

Everything stays on the device. There is no account, no server and no tracking.

German UI with an English translation.

## Features

- Month list with one-tap workdays (swipe right) and vacation (swipe left);
  day sheet with editable start, end and break.
- Target hours and default times per weekday, set independently. The target is
  frozen per day, so later schedule changes never rewrite past days.
- Overtime account with initial balance; year overview with chart.
- Vacation account: starting value, yearly entitlement on 1 January, nothing
  expires; quick vacation booking from a start date and an end date or a number
  of days — weekends, public holidays of the chosen German state and days that
  already have entries are skipped.
- Categories for working times (e.g. "Switzerland"): a category either counts as normal work time
  and only labels it, or keeps its time separate from target, actual time and overtime (paid
  separately); export one category for a month, a year or any period as PDF/CSV with its total.
- Review list of days that may deserve a credit (weekend work, notes mentioning
  vacation).
- PDF per month or year, CSV (semicolon, German decimals).
- Automatic JSON backup after every change to a folder of your choice (e.g.
  iCloud Drive), 30 daily copies; restore from any of them.
- Import of `.mytimebackup` files from *myTime – Zeiterfassung*, with a preview
  of the totals before anything is saved (format: `docs/mytime-backup-format.md`).

## How Toki calculates

- **Worked** = Σ work entries (end − start − break).
- **Target of a day** = 0 when the day has no entries or an absence entry
  (vacation, sick, child sick, public holiday, special leave), otherwise the
  target frozen on that day.
- **Overtime of a day** = worked − target + manual correction; 0 on credited
  days and while a work entry has no end yet. An overtime-reduction entry keeps
  the day's target, so the day shows −target.
- **Overtime account** = initial balance + Σ overtime of all days.
- **Vacation balance on a date** = starting value + entitlement for every
  1 January after the starting date − vacation days + credits.

These rules reproduce myTime's own totals for imported data before any credit is
applied.

## Layout

| Path | Content |
|---|---|
| `Packages/TokiCore/` | Pure Swift rules (Foundation only): accounts, credits, German public holidays, quick vacation planner, location days, myTime import, CSV, backup |
| `Toki/` | SwiftUI + SwiftData app, PDF export, string catalogs (source language German) |
| `TokiUITests/` | End-to-end tests in the simulator |
| `docs/` | myTime backup format |
| `tools/make-icon.swift` | Renders the app icon |

## Build and test

Requires Xcode 26 (iOS 17 deployment target). The project uses folder-synchronised
groups, so new files are picked up without editing the project file.

```bash
cd Packages/TokiCore && swift test          # rules, runs on macOS (and Linux)

xcodebuild test -project Toki.xcodeproj -scheme TokiUITests \
  -destination "id=<simulator id>" -parallel-testing-enabled NO
```

UI tests launch the app with `-uiTesting` (Debug only): an empty in-memory store.
Location tests need location access for Toki in the simulator and a simulated
location (`xcrun simctl location <simulator id> set <lat>,<lon>`). The geofence
test moves the location from outside and runs only with
`TEST_RUNNER_TOKI_GEOFENCE_TEST=1` (see `TokiUITests/GeofenceUITests.swift`).

Restoring a backup through the real document picker: put a backup named
`Toki-Test-Sicherung.json` into the simulator's "On My iPhone" (the `File Provider Storage` folder of
the `com.apple.DocumentsApp` LocalStorage group container) and run with
`TEST_RUNNER_TOKI_RESTORE_TEST=1` (see `TokiUITests/RestoreBackupUITests.swift`).

To build for your own device, change the bundle identifier and the development
team in the project settings.

## Contributing

Issues and pull requests are welcome. Please read `CONTRIBUTING.md` first —
contributions need a short licence grant so the project can stay flexible.

## Support

Toki is free, without ads and without tracking. If it saves you time, you can support its
development with [a small donation via PayPal](https://www.paypal.com/donate/?hosted_button_id=W3MA5RQWWJS2U).

## Licence

The source code is licensed under the [Mozilla Public License 2.0](LICENSE).

The name "Toki" and the app icon are not covered by the licence; please use your
own name and icon for a published fork.

## Privacy

<https://www.abrechen2.de/apps/toki/datenschutz/> (German) ·
<https://www.abrechen2.de/en/apps/toki/privacy/> (English)
