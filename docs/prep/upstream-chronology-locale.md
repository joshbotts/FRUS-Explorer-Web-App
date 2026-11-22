# Upstream: Chronology's labels take a locale (FRUS-Explorer#1912)

FRUS-Explorer#1968, merged as `91842c0bf5a7b638f45c3d7919afe85e2cd2fb4c` on 2026-11-22, with #1913's and #1928's changes. The calls that gained `locale:`, each `locale: Locale = .autoupdatingCurrent`, the reader's own as before, so the app's labels are unchanged:
- `ChronologyGrouping.group(_:viewBucket:ascending:locale:)`: each section's `displayLabel`, in the locale's own calendar ("February 15, 1969" in `en_US`, "15 February 1969" in `en_GB`);
- `ChronologyGrouping.makeChart(fromCounts:viewBucket:maxSeries:locale:)`: each bucket's `label`, at the view's granularity.

`makeChart(from:maxSeries:)` takes none: a bucket's label is its group's, so it is in the locale `group` was given.

## The web's steps

1. **The pin move:** S12d's goes to the tag `1.0-release` (`08e8bac8`) and no further, and this merged after it, so a later pin move carries it: to a `v2` commit at or past `4556c4d5`, which carries this batch's three pull requests (#1967, #1968 and #1969), by COORDINATION §5's checklist.
   - The golden files' source digest covers `FRUSCoreKit/` and `FRUSExplorer/`, so the move stales them. Nothing on the indexing path changed in this batch, so which export remakes them is the owner's choice, as at every pin move.
2. **The labels:** S24f's server writes the kit's labels again in US English. That is `ChronologyLabels`, at the end of `Sources/FRUSLightAPI/Chronology.swift`, whose opening comment ends "until the kit takes a locale (FRUS-Explorer#1912)".
   - Pass `SearchItem.locale` to the `group` call (about :284) and the `makeChart(fromCounts:…)` call (about :292).
   - Take the answer's labels from `ChronologyDateGroup.displayLabel` and `ChronologyChartBucket.label`. The kit labels a section at its own granularity and a bucket from the counts at the view's, as the server's `granularities` map does (about :288–295), so the map goes too.
   - Remove `ChronologyLabels.label(forBucketKey:granularity:)` and its mirror of the kit's `sortDate(forBucketKey:)`. `firstDay(ofBucketKey:)`, the answer's ISO first day, is the server's own, and stays.
   - The file's opening comment then says the kit writes the labels in `SearchItem.locale`.
3. **Tests:** `ChronologyParityTests` hold the labels to the kit's call, and a test checks that a day's section is labelled "February 15, 1969" on Linux.
4. **Records:** a DEVLOG follow-up entry above Session 24f's.

## Taken

By the pin move to `4556c4d5`, `v2`'s head (the log's entry, "Session 24f, second follow-up", above Session 24f's follow-up, which stands for step 4's entry), steps 1 to 3:
- `ChronologyRoutes.assemble` passes `SearchItem.locale` to `group` and to `makeChart(fromCounts:…)`, and takes each section's label from `displayLabel` and each bucket's from `label`. `ChronologyLabels`, with its mirror of the kit's `sortDate(forBucketKey:)`, and the `granularities` map are gone. `firstDay(ofBucketKey:)` stays, as `ChronologyRoutes.firstDay(ofBucketKey:)`.
- `ChronologyParityTests` take the labels from the kit's calls in `en_US`. `theLabelsAreTheKitsInUSEnglish` holds, through the server's assembly on Linux, a day's section, its bucket and its table row as "February 15, 1969", a month's as "February 1969" and a year's as "1969". `AnalyticsRulesTests` holds the capped chart's buckets at the view's granularity ("October 1, 1962"), and `AnalyticsMirrorParityTests` the server's `group` call with its locale.
- `Chronology.swift`'s opening comment says the kit writes the labels in `SearchItem.locale`, and SPEC's Chronology no longer says the server writes them again.
