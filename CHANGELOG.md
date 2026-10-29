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

[1.0]: https://github.com/Abrechen2/Toki/commits/main
