# Upstream: DecadeFrequency's initialiser is public (FRUS-Explorer#1928)

FRUS-Explorer#1968, merged as `91842c0bf5a7b638f45c3d7919afe85e2cd2fb4c` on 2026-11-22, with #1912's and #1913's changes. The initialiser, as merged: `public init(decadeStart: Int, count: Int)`.

## The web's steps

1. **The pin move:** S12d's goes to the tag `1.0-release` (`08e8bac8`) and no further, and this merged after it, so a later pin move carries it: to a `v2` commit at or past `4556c4d5`, which carries this batch's three pull requests (#1967, #1968 and #1969), by COORDINATION §5's checklist.
   - The golden files' source digest covers `FRUSCoreKit/` and `FRUSExplorer/`, so the move stales them. Nothing on the indexing path changed in this batch, so which export remakes them is the owner's choice, as at every pin move.
2. **The decades:** `Sources/FRUSLightAPI/CorpusAnalytics.swift` carries its own decade type, `Decade`, because the kit's initialiser was internal (about :788–806: `decadeData`, whose comment says so, and the struct). Build the kit's `DecadeFrequency` instead, as the app's `AnalyticsView` does (about :375), and remove the web's own type.
3. **Tests:**
   - `CorpusAnalyticsParityTests` still hold every series over the fixtures to the kit's;
   - `AnalyticsMirrorParityTests` can hold the sum's `DecadeFrequency(decadeStart: $0.key, count: $0.value)` line to the app's.
4. **Records:** a DEVLOG follow-up entry above Session 24f's.

## Taken

By the pin move to `4556c4d5`, `v2`'s head (the log's entry, "Session 24f, second follow-up", above Session 24f's follow-up, which stands for step 4's entry), steps 1 to 3:
- `CorpusAnalyticsView.decadeData` builds the kit's `DecadeFrequency`, as `AnalyticsView.decadeSeries(for:)` does, and gives the documents' decades as the service gives them. The web's `Decade` is gone.
- `AnalyticsMirrorParityTests` holds the sum's lines to the app's: the guard, the sum, and `.map { DecadeFrequency(decadeStart: $0.key, count: $0.value) }` with its sort. `CorpusAnalyticsParityTests` hold every series as before.
