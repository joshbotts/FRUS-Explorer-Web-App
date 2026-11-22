# Upstream: Corpus Analytics keys its occurrence cache apart (FRUS-Explorer#1913)

FRUS-Explorer#1968, merged as `91842c0bf5a7b638f45c3d7919afe85e2cd2fb4c` on 2026-11-22, with #1912's and #1928's changes. How the caches are keyed now: the occurrence series by year and volume (`termOccurrencesByYearAndVolume(term:volumeIds:)`) has a dictionary of its own, `yearVolumeOccurrenceCache`, keyed by `scopedCacheKey(term:volumeIds:)` as the documents series is, with no `occ:` prefix, and `invalidateCache()` clears it with the others. `termOccurrencesByYear(term:volumeIds:)` is summed from that series, so both occurrence series are apart from every documents series.

## The web's steps

1. **The pin move:** S12d's goes to the tag `1.0-release` (`08e8bac8`) and no further, and this merged after it, so a later pin move carries it: to a `v2` commit at or past `4556c4d5`, which carries this batch's three pull requests (#1967, #1968 and #1969), by COORDINATION §5's checklist.
   - The golden files' source digest covers `FRUSCoreKit/` and `FRUSExplorer/`, so the move stales them. Nothing on the indexing path changed in this batch, so which export remakes them is the owner's choice, as at every pin move.
2. **One service:** S24f's `ServedIndex` keeps a second `CorpusAnalyticsService`, `occurrences`, for the occurrence series alone.
   - It is declared in `Sources/FRUSLightAPI/ServedIndex.swift` (about :52, made at about :100), and used in `Sources/FRUSLightAPI/CorpusAnalytics.swift` (about :495–498, under a comment that names #1913).
   - Ask `analytics` for both series, and remove `occurrences`.
3. **Tests:**
   - S24f's analytics route and parity tests hold as before;
   - a new test checks that a term spelt `occ:` plus a term gets its own series.
4. **Records:** a DEVLOG follow-up entry above Session 24f's.

## Taken

By the pin move to `4556c4d5`, `v2`'s head (the log's entry, "Session 24f, second follow-up", above Session 24f's follow-up, which stands for step 4's entry), steps 1 to 3:
- `ServedIndex`'s `occurrences` is gone, and `CorpusAnalytics.swift` asks `analytics` for both occurrence series. `AnalyticsMirrorParityTests` holds the two lines.
- `CorpusAnalyticsParityTests.aTermSpeltOccAndAWordGetsItsOwnSeries`, over the fixture index through the API: a documents chart for `occ:treaty` asked after the occurrences of "treaty" over the whole corpus, and before them in a scope, each the kit's from a host's own service that has cached nothing, and the two series apart. It sits there, not in the route tests, since the fixture index's occurrences are what the parity suite already counts. The route and parity suites hold as before.
- SPEC's Corpus Analytics no longer names a second service.
