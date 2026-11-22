# Upstream: Related Documents' rows read a user source (FRUS-Explorer#1907)

FRUS-Explorer#1967, merged as `4556c4d550c702f4661b61db5c64552a4d1393c7` on 2026-11-22, with #1927's change. The parameter, as merged: `RelatedDocumentsEngine.rank(anchor:anchorYear:weights:scopeVolumeIds:limit:includeSnippets:userSource:includeOffIndexLeads:dependencies:)` takes `userSource: SearchUserSource = .index`, after `includeSnippets`.
- Only a shown row's line reads it, through #1902's `IndexingPipeline.documentSnippets(forKeys:maxLength:userSource:)`. With `.attachedStore(userId:)`, a row's line is that user's summary where they have one, and otherwise the document's opening text from the index. With `includeSnippets: false` the source changes nothing.
- A read that fails, as one of an attached store the index does not have, leaves the rows without lines.
- From the index, the default and the app's call, the lines are read by the statement they were read by before, which `RelatedDocumentsHostTests` pins by its text.

## What it unblocks

A related document that the reader has summarised shows the summary, as on the Mac. Today the web shows its opening text: the README's Known gaps say "A related document the user summarised still shows its opening text too, until the kit's engine takes a user source". With #1902's call (step 3), a Suggested Next lead does too.

## The web's steps

1. **The pin move:** S12d's goes to the tag `1.0-release` (`08e8bac8`) and no further, and this merged after it, so a later pin move carries it: to a `v2` commit at or past `4556c4d5`, which carries this batch's three pull requests (#1967, #1968 and #1969), by COORDINATION §5's checklist.
   - The golden files' source digest covers `FRUSCoreKit/` and `FRUSExplorer/`, so the move stales them. Nothing on the indexing path changed in this batch, so which export remakes them is the owner's choice, as at every pin move.
2. **The call:** `Sources/FRUSLightAPI/RelatedDocuments.swift`'s `RelatedDocumentsEngine.rank(` call (about :209) passes a user source:
   - `.attachedStore(userId:)` for the request's user, where the served index has the user store attached (`ServedIndex.attachesUserStore`), as the search has since S17d;
   - `.index` otherwise.

   `Sources/FRUSLightAPI/ProjectLeads.swift`'s call (about :306) passes `includeSnippets: false`, so it reads no lines and needs no source.
3. **#1902's own call:** in the same pull request or beside it, Project Home's leads (`Sources/FRUSLightAPI/ProjectHome.swift`, the `documentSnippets(forKeys:)` call at about :193) pass the same source to `documentSnippets(forKeys:maxLength:userSource:)`. This is the first of the README's "Three calls the kit made public wait for a follow-up".
4. **Tests:**
   - a route test where one user's summary is a related row's line for that user, and not for another, and the same for a Suggested Next lead's line;
   - the Related Documents parity tests still hold over the fixtures.
5. **Records:**
   - a DEVLOG follow-up entry above Session 23d's (PLAN rule 5);
   - the Known gaps sentence quoted above goes, and the "Three calls" bullet loses its first call.

## Taken

By the pin move to `4556c4d5`, `v2`'s head (the log's entry, "Session 24f, second follow-up", which stands for step 5's entry: it sits above Session 24f's follow-up and says it does #1907's web side), steps 1 to 5:
- `RelatedDocumentsRoutes.ranked` passes the kit's `rank` a `userSource`, the one `SearchUsers.summarySource(for:context:served:)` names: `.attachedStore(userId:)` for the user the request searches as, on the search's terms, where the served index attaches the user store, and `.index` for a request that acts for no one or a server that keeps no user data. The route takes the router's `SearchUsers`, by its existing line in `Routes.swift`.
- `ProjectLeads.swift`'s call passes `includeSnippets: false`, and is unchanged.
- Project Home's leads (`ProjectHomeRoutes.withLines`) pass the same source to `documentSnippets(forKeys:maxLength:userSource:)` for the user under /me (`SearchUsers.summarySource(of:served:)`), and `ProjectHistoryParityTests` holds the server's two lines beside the app's call.
- `SummaryLinesTests.eachReadersSummaryIsTheirLineAlone`, behind a proxy that signs two users in: one user's summary of d2 is its line in d1's Related list and on a Suggested Next lead for her, and d2's text for the other, and, in Related, for a request that names no one. The synthetic export gets a citation from d1 to d2 for it, since it holds no archival container or cross-reference of its own (`UserDataFixture`'s `edits`). `RelatedDocumentsParityTests` hold every fixture document's list through the API, now read through the single user's source, to the kit's ranking from the index.
- The README's Known gaps sentence is gone, and the "Three calls" bullet keeps its other two.
