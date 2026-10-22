# myTime backup format (`.mytimebackup`)

Reverse-engineered from a backup created by *myTime – Zeiterfassung* 26.3.2
(~1.2 MB for three years of data). The file is plain UTF-8 JSON, not encrypted
or compressed. Nothing here comes from the app binary — only from exported
data, PDF exports and screenshots. Values below are examples.

## Top level

| Key | Content |
|---|---|
| `appVersion` | `"26.3.2"` |
| `exportDate` | ISO 8601 UTC |
| `jobsBackup[]` | one element per job (`job`, `defaultDays[7]`, `timeJob`) |
| `yearsBackup[]` | one element per calendar year: `timeYear` + `timeMonths[12]` |
| `settingsBackup` | export (PDF/CSV) and overview settings |
| `userBackup`, `predefinedNotesBackup`, `id` | not needed for import |

Most scalar fields carry a `_value` suffix (`name_value`, `note_value`, …).
Every object has `creationDate`, `lastModifiedDate` and a `dtoReferences` dict
of UUIDs.

## Dates and time zone

All timestamps are UTC instants. A calendar day is stored as **local midnight
in Europe/Berlin**, e.g. `2030-05-31T22:00:00Z` = 2030-06-01. Convert to
`Europe/Berlin` before taking the date — a naive UTC date is off by one.

## Job (`jobsBackup[].job`)

- `name_value` — job name, e.g. `"Firma"`
- `configuration_value.overtimeConfig_value`
  - `isOvertimeCalculationOn_value` (bool)
  - `initialOvertimeHours_value` — starting balance in hours, e.g. `10`
- `configuration_value.vacationConfig_value`
  - `isVacationDaysCalculationOn_value` (bool)
  - `vacationDaysPerYear_value` — e.g. `30`
  - `initialVacationDays_value` — e.g. `5`
  - `vacationDaysRenewalDate_value` — e.g. `2029-12-31T23:00:00Z` (= 1 Jan)
- `hiddenEntryTypeIds_value[]` — entry types hidden in the picker

`timeJob` holds cached totals: `totalHours` (hours worked, all time) and
`totalOvertimeHours` (**excluding** the initial overtime; the UI shows
initial + this).

## Default days (`jobsBackup[].defaultDays[7]`)

Template per weekday. `weekday` is Apple's numbering: **1 = Sunday … 7 =
Saturday**. Fields: `startTime_value` / `endTime_value` (decimal hours, 8 =
08:00, 16.5 = 16:30), `breakEntries_value[].totalHours_value`,
`plannedHoursOfDay_value` (target hours), `entryType_value`.

Days with target 0 (weekends) still have a template with `plannedHoursOfDay_value` 0.

## Years, months, days

`yearsBackup[].timeYear`: `yearNumber`, cached `totalHours`,
`totalOvertimeHours`, `totalVacationDays` (days taken in that year).

`timeMonths[].days[]`:

| Key | Meaning |
|---|---|
| `date` | the day (see time zone above) |
| `plannedHoursOfDay_value` | **target hours for that specific day** — frozen per day, so historical targets survive schedule changes |
| `entries[]` | 0..n entries |

Days without entries exist too (empty `entries`).

## Entries

| Key | Meaning |
|---|---|
| `entryType_value` | full embedded entry type object (see below) |
| `startDate_value`, `endDate_value` | UTC instants; absent for day-type entries |
| `breakEntries_value[]` | `totalHours_value` per break |
| `overtimeHours_value` | manual overtime delta in hours; negative for "Überstundenabbau" (e.g. −5) |
| `fractionOfDay_value` | `10` in all data seen (full day; presumably tenths) |
| `eventHours_value` | 0 in all data seen |
| `note_value` | free text |
| `entryDate` | same as the day's `date` |

## Entry types seen in the data

| ID | Name | category | hourMultiplicator |
|---|---|---|---|
| `10001111-0000-…` | Arbeit | 1 | 1 |
| `10001111-0001-…` | Arbeit (mit Pausen) | 1 | 1 |
| `10001111-1001-…` | Urlaub (ohne Stunden) | 2 | 0 |
| `10001111-2001-…` | Krankheit (ohne Stunden) | 2 | 0 |
| `10001111-4001-…` | Feiertag (ohne Stunden) | 2 | 0 |
| `10001111-6000-…` | Überstundenabbau | 2 | 1 |

The picker also offers "Kind Krank", "Sonderurlaub", "Home Office",
"Reisezeit", "Kurzarbeit" (not used in the data).

## How myTime computes the numbers (verified against the UI)

- **Day overtime** = worked hours (end − start − breaks) − `plannedHoursOfDay`.
  Vacation, holiday and sick days carry target 0. An "Überstundenabbau" entry
  has `overtimeHours_value` = −target; adding it *and* subtracting the target
  would count the reduction twice — the day simply shows −target.
- **Days without entries** contribute nothing.
- **Total overtime** = `initialOvertimeHours` + Σ day overtime (matches the
  month screen).
- **Remaining vacation** = `initialVacationDays` + `vacationDaysPerYear` × each
  year from the year *before* the renewal date through the current year −
  vacation days taken.
- There is **no** way to credit vacation days; users work around it with notes
  such as "+1 Urlaubstag", which the calculation ignores.
