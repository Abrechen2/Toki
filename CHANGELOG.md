# Changelog

All notable changes to Toki are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0] - Unreleased

First version for the App Store.

### Added

- Working hours, overtime and vacation account for iPhone, with a month list,
  one-tap workdays (swipe right) and vacation (swipe left), and a day sheet for
  start, end and break.
- Target hours and default times per weekday; the target is frozen per day, so
  later schedule changes never rewrite past days.
- Overtime account with an initial balance and a year overview with chart.
- Vacation account with a starting value and a yearly entitlement; quick
  vacation booking that skips weekends, public holidays of the chosen German
  state and days that already have entries.
- Vacation credits: whole extra vacation days for single days such as a weekend
  assignment or a travel day, plus a review list of days that may deserve one.
- Half vacation days, fractional credits (e.g. 1.5 days) and vacation
  corrections with a required reason.
- Categories for working times: a category either only labels normal work time
  or keeps its time separate from target, actual time and overtime. One
  category can be exported for a month, a year or any period as PDF/CSV.
- Automatic entries by location: arriving at and leaving the office are
  recorded in the background.
- First-launch assistant for workdays, targets, start time, legal break,
  vacation entitlement, current balances and German state — or a myTime import
  instead.
- PDF export per month or year and CSV export (semicolon, German decimals).
- Automatic JSON backup after every change to a folder of your choice, with 30
  daily copies and restore.
- Import of `.mytimebackup` files from *myTime – Zeiterfassung*, with a preview
  of the totals before anything is saved.
- German UI with an English translation.
- "A project by <abrechen2 />" credit on the More screen.

### Fixed

- Choosing a file to restore or import did nothing.
- Vacation entries with a note showed up as credit candidates.
- Days without entries kept a stored target (e.g. 0 from an import) instead of
  following the current schedule.
- Job settings were lost when leaving the screen without saving; the default
  values now show the weekly target sum.
- Arriving at or leaving the office could send the same message twice.
- Restore and import save everything in one transaction; a failed save rolls
  back and shows no confirmation.
- Night templates (22:00–06:00) end on the next day; myTime imports keep
  wall-clock times on daylight-saving days.
- Recomputing recent days at launch no longer deletes automatic entries after
  a backup restore.

## Beta builds (TestFlight)

Every TestFlight build of version 1.0, newest first. The build number is the
build's start time in UTC (`YYYYMMDDhhmm`); each entry lists what changed since
the previous build.

### 202610250854 (2026-10-25)
- Quick entry: up to three presets on an empty day ("office day" from the
  weekly plan, "like the last workday", own presets), then adjust the end by
  −0:15 / +0:15 / +0:30 / +1:00 or undo.
- Select several empty days and book them at once, with undo.
- More → Presets: create, edit and delete presets; save a finished day as preset.
- Documentation mode: warns before booking a preset that breaks the ArbZG.
- Public holidays show their name on the day; no office day on holidays.
- Small fixes to texts, line breaks and time zones.

### 202610242344 (2026-10-25)
- ArbZG documentation mode in the new design: day summary, one card for
  violations with reasons, "ArbZG check" list, travel switch in the block,
  gaps marked as break or no break.
- Replacement rest day with deadline and preview; month close with a status
  per day, overdue months in red.
- PDF with name and employer, time zones and "entered later on".
- Clock hours (8:15) in the documentation mode, "Ø 24 weeks" tile.
- Removing the record completely also resets schedule changes.

### 202610241813 (2026-10-24)
- ArbZG documentation mode complete: maximum working time, breaks, rest
  periods, travel time, Sunday and holiday work with replacement rest day;
  monthly statement as PDF/CSV with versions, archive and change log.
- Warning when the start date lies in the past; the debit shows on the day.
- Switching the mode off without a statement removes it completely.
- "Actual" shows the credit, the ArbZG time below it; later entries are marked.
- Typographic minus, no truncated titles, time zones in the month list.

### 202610240850 (2026-10-24)
- Preview of the ArbZG documentation mode (off by default): stamping card with
  automatic statutory break, days as a timeline across time zones, checks with
  reasons, configurable rules.
- Not yet included: location stamping in the mode, replacement rest days,
  statement PDF.

### 202610230723 (2026-10-23)
- Office location: only one message per arrival and per departure.
- "A project by <abrechen2 />" at the bottom of the More screen.

### 202610221924 (2026-10-22)
- Empty days follow the current target instead of a stored 0 from an import.
- Default values show the weekly target sum.
- Job settings save on every change; going back without saving keeps edits.

### 202610221506 (2026-10-22)
- Categories for working times, either as a label or kept separate from target
  and overtime; export one category for a month, a year or any period.

### 202610221415 (2026-10-22)
- Fixed: choosing a file to restore or import did nothing.

### 202610221358 (2026-10-22)
- Half vacation days, fractional credits (e.g. 1.5 days) and vacation
  corrections with a required reason.

### 202610221229 (2026-10-22)
- Fixes from the pre-submission review: restore and import in one transaction,
  failed saves roll back, bounded number fields, night shifts (22:00–06:00) end
  on the next day, myTime import keeps wall-clock times on daylight-saving days,
  office changes reconfigure location monitoring.
- Attached to App Store version 1.0.

### 202610221207 (2026-10-22)
- First-launch assistant (workdays, target, start, break, vacation entitlement,
  current balances, German state) or a myTime import instead.
- Vacation entries with a note are no longer credit candidates.
- Impossible numbers in imported and restored files are rejected.
- Recomputing at launch no longer deletes automatic entries after a restore.
- Dates follow the app language; privacy policy linked at www.abrechen2.de.

### 202610212121 (2026-10-21)
- Notification permission is requested while setting up the office, not on saving.

### 202610212107 (2026-10-21)
- Fixed: the app claimed to be at the office while far away.

### 202610212035 (2026-10-21)
- Saving is confirmed visibly; an open stay is dropped when the office moves.

### 202610212013 (2026-10-21)
- Fixed: office setup failed before location access; address search was hidden.

### 202610211945 (2026-10-21)
- Automatic entries by office location (arrival and departure in the background).

### 202610211828 (2026-10-21)
- Automatic backup to a folder in iCloud Drive.

### 202610211814 (2026-10-21)
- Job settings like myTime, with a target per weekday.

### 202610211806 (2026-10-21)
- Adjust start, end and break in the quick workday entry.
- Uploaded after 202610211814 but does not contain its job settings.

### 202610211758 (2026-10-21)
- Book a workday with one tap.

### 202610211747 (2026-10-21)
- App icon with the kanji 時.

### 202610211746 (2026-10-21)
- First build: overtime and vacation account, quick vacation booking, myTime import.

[1.0]: https://github.com/Abrechen2/Toki/commits/main
