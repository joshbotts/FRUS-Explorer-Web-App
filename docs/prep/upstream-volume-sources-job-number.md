# Upstream: the Sources outline reads a CIA job's number (FRUS-Explorer#1929)

FRUS-Explorer#1948, merged as `9e582653e0fac9a8778e2dbfee170ed4b0067223` on 2026-11-17. A volume with a CIA job row, for testing: `frus1961-63v10` (Cuba, January 1961–September 1962), whose Sources name 13 jobs: in a 298-volume library *DCI (McCone) Files: Job 80-B01285A* counts 150 neighbours and *DCI Files: Job 54-00499R* none. The same pull request moves the index to version 75 (FRUS-Explorer#1909), so this pin move is that one's too.

## The web's steps

1. **The pin move:** move to a `v2` commit at or past `9e582653e0fac9a8778e2dbfee170ed4b0067223`. The golden files take the owner's choice of export.
2. **The outline:** `Sources/FRUSLightAPI/VolumeSources.swift` mirrors the app's rule (`let job = trimmed(entry.jobNumber)`, about :180) over the kit's `volumeSources(forVolumeId:)` (about :94). So a CIA job's row gets its neighbours button with no change here.
   - Check `SourceExplorerParityTests`, which hold the rule's lines (about :758), and the outline's route tests.
   - If the fixtures have no CIA job row, add one to a synthetic export.
3. **Records:** S22d's follow-up named this gap in its log entry. A DEVLOG follow-up entry above Session 22d's says it is closed.

## Taken

By S12d's pin move to the tag `1.0-release` (`08e8bac8`), which holds `9e582653` (the log's entry, Session 12d):
- The outline needed no change: `Sources/FRUSLightAPI/VolumeSources.swift` mirrors `makeNeighborsTarget`, and `SourceExplorerParityTests` holds its lines, which #1948 leaves as they were.
- The fixtures have CIA job rows: frus1969-76ve09p1's Sources name four jobs. `SourceExplorerRecordParityTests.theOutlinesAffordancesAreTheViews`, which held that no row carried a job number, now holds each job row's button to its job, and its count to the neighbours' page.
