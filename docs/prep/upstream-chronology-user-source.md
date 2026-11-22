# Upstream: Chronology's rows read a user source (FRUS-Explorer#1927)

FRUS-Explorer#1967, merged as `4556c4d550c702f4661b61db5c64552a4d1393c7` on 2026-11-22, with #1907's change. The parameter, as merged: `IndexingPipeline.documentsInDateRange(_:scopeVolumeIds:ascending:limit:userSource:)` takes `userSource: SearchUserSource = .index`.
- With `.attachedStore(userId:)`, a row's `summary` is that user's, from `user_search` in the attached store, and nil where they have none. Every other field, and which rows come back in which order, is the index's.
- The statement gathers the user's summaries in one scan of the store's `user_search` (a `MATERIALIZED` CTE), since FTS5 indexes none of its unindexed columns, and joins them after the index's two tables. Each call therefore reads every user's rows, and its cost grows with the store.
- An attached store asked for where the index has none throws `IndexingError`: a reader's summaries are refused, not read from the index.
- From the index, the default and the app's call, the statement is the one it was before, by text and binds, which `ChronologyUserSourceTests` pins.

## The web's steps

1. **The pin move:** S12d's goes to the tag `1.0-release` (`08e8bac8`) and no further, and this merged after it, so a later pin move carries it: to a `v2` commit at or past `4556c4d5`, which carries this batch's three pull requests (#1967, #1968 and #1969), by COORDINATION §5's checklist.
   - The golden files' source digest covers `FRUSCoreKit/` and `FRUSExplorer/`, so the move stales them. Nothing on the indexing path changed in this batch, so which export remakes them is the owner's choice, as at every pin move.
2. **The call:** `Sources/FRUSLightAPI/Chronology.swift` calls `documentsInDateRange` at about :256. Pass `.attachedStore(userId:)` for the request's user where the served index has the user store attached (`ServedIndex.attachesUserStore`), and `.index` otherwise: asked of an index with none attached, the call throws.
3. **Tests:** a Chronology route test where one user's summary is a row's line for that user and not for another. `ChronologyParityTests` still hold over the fixtures.
4. **Records:** a DEVLOG follow-up entry above Session 24f's.

## Taken

By the pin move to `4556c4d5`, `v2`'s head (the log's entry, "Session 24f, second follow-up", above Session 24f's follow-up, which stands for step 4's entry), steps 1 to 3:
- `/api/v1/chronology` passes `documentsInDateRange` the source `SearchUsers.summarySource(for:context:served:)` names, as Related Documents' rows do: the user the request searches as, where the served index attaches the store, and the index otherwise. The export and the plate pass `.index`: the chart's table and figure read no row's summary, and the attached store's statement reads every user's rows of `user_search` at each call.
- `SummaryLinesTests.eachReadersSummaryIsTheirLineAlone`: one user's summary of d2 is its Chronology row's line for her, and d2's head for another and for a request that names no one. `ChronologyParityTests` hold the fixture ranges through the API, now read through the single user's source, to the kit's rows from the index.
- SPEC's Chronology says a row's summary is its reader's.
