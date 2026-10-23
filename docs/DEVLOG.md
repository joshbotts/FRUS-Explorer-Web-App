# Development log

One entry per session, newest first.

## Session 11f: the timeline and the concordance, over the API and in the browser app

23 October 2026 · branch `claude/s11f-timeline-concordance-97c312` · upstream `af41efa4`, unchanged

The last phase-1 feature row, held until the web edition caught up with FRUS Explorer 1.0: the search window's timeline and concordance readings, each naming the set it read, as the Mac's do. Both are computed with kit code that #1664 made public, so no upstream pull request was needed.

**What the Mac's window does**, mapped at the pin:

- **The Reading picker** (`ResultReading`, app code): List, Timeline, Concordance and Collocates, one segmented control in the toolbar, whose tooltip says which set each covers: "The concordance covers this page; the others cover the whole retained set."
- **The timeline** (`DocumentTimelineView`, app code) plots the window's `displayedResults`: the 7,500 results it keeps, in its order, less what Checklist Mode hides. It dates them with the kit's `IndexingPipeline.datesByDocumentKey(_:)`, groups them by the first four characters of each date, and shows a Chart or a List of each year's documents; a result with no date is left out and counted. Above it, when the results kept reach their ceiling, `ResultSetScope.timelineBiasCaption` says the shape is the ranking's.
- **The concordance** (`ConcordanceView`) is the kit's `SearchService.concordance(for:parameters:radius:)` over `pagedResults`, the page on screen, with the kit's radius of 60. Align by sorts the lines it holds by `KWICSort`; its count is `ResultSetScope.concordanceCountDescription`, which names the page when there is more than one; two notes say what the per-document bound left out and which documents gave no line.

**The API**

- **`/search/timeline`** takes a search's fields, with its page and order as they stand, and counts by year the results the app keeps of it. The years and counts are the kit's Years facet over the keys of those results (`resultSetFacets(parameters:request:documentKeys:)`, the kit's route for a list it describes by its keys), which keys a document by its date's first four characters, the rule the Mac's timeline groups by, and which its year filter matches (`substr(date_iso, 1, 4)`). The results kept are the date order's, kept for the last two searches, and they stop when no request waits for them; the facet over their keys reads only the rows they name, and is kept beside the panel's sections. With `documents=true` each year carries its documents, the results kept whose date the kit keys by that year, in the order `sort` gives them; `retainedCount` says how many were kept.
- **`/search/concordance`** takes a search's fields and its page, and gives the kit's lines for the documents of the page `/search` gives, by the draft's names (`keyword`, `characterOffset`), each with the title its row draws. `orders` gives each `KWICSort` order as positions in the lines, with the kit's labels in `orderChoices`, so the browser app changes the order without asking again. `omittedCount` and `documentsWithoutLines` are the kit's. The kit keeps its bound on one document's lines internal, so `linesPerDocumentLimit` gives it as read from the answer when it left any line out: a document it cut short gave exactly that many.
- **Neither counts the match,** which `/search` counts: over the full corpus an exact-word count takes about 20 seconds, so each count a reading added would have cost that again. The draft's concordance parameters are refused as `UNSUPPORTED_PARAMETER`, each with what this concordance does instead.

**The browser app**

- **Reading**, beside Sort, offers List, Timeline and Concordance, in the Mac's words and with its tooltip, and waits for a match, as the Mac's does. A search that found nothing says so in any reading. Collocates wait for phase 4.
- **The timeline:**
  - a chart of a column for each year, from the first year to the last, one series in one colour, with rounded data ends, a hairline grid and the dataviz validator's checks passing in both appearances; dark mode draws its columns in a step of its own, `#3987e5`, since the dark accent is too light for a mark;
  - the **Table of the counts** beneath it, the chart's text alternative, which the keyboard opens, and a line that names the year and count under the pointer;
  - its **List** mode, each year's documents under it, in the order Sort gives them;
  - the Mac's caption when the search reaches the 7,500 results it keeps, its line for the results with no date, and its view of none dated, alone;
  - no pager, since it covers every result kept.
- **The concordance:**
  - each occurrence on a line, the term in a column between its contexts, 60 characters a side in a monospaced face, so the margins line up;
  - wider than a narrow screen, the lines scroll sideways, as the Mac's do, opening with the terms in view, and each line's document stays at the left of what the screen shows;
  - **Align by** with the kit's four orders, Left context first, as the Mac's;
  - its count, "1,198 occurrences in the 20 documents on this page", its view of no aligned occurrences and its two notes, with the singulars the Mac's lack;
  - a line opens its document, and reads aloud as the Mac's VoiceOver label reads it.
- **The reading, the timeline's mode and the concordance's order are in the search's address,** so Back from a document shows the search as it was, as the Mac's window stays behind a document it opens. A new search, a facet's narrowing and a page keep them; another reading opens the timeline on its chart, as the Mac's does.

**Checked**

- **Through the API, beside the kit and the app's rule,** over the fixture index imported as an export (FRUSParityTests, `ReadingsAPIParityTests`):
  - every parity query's timeline with its documents, and a sixth of them in each order of the date, is the Mac's grouping of the 7,500 results the kit keeps: 439 timelines, 359 across more than one year and 208 with undated results, and 123 orders of the date that order a year's documents otherwise;
  - each year's documents are those the kit's own year filter keeps among the results kept, and where the search keeps its whole match, its count is the facet panel's over the match, the kit's other route to the same years: 46 years of 6 searches;
  - a match larger than what is kept is counted over what is kept: with 7 kept, the timelines of 8 searches are the Mac's over their 7 best, and none is the whole match's;
  - every fourth query's concordance, in pages of 7, by relevance and in both orders of the date, is the kit's for the page `/search` gives, in each of the kit's orders: 327 pages, 77 with documents that gave no line, 11 cut at the kit's 200 lines a document, which the answer gives, and 163 pages in an order of the date whose lines the date orders otherwise;
  - the sets both readings read are held to the app's source at the pin: the timeline's grouping, `displayedResults` and `pagedResults`, the kit's own radius, and the 7,500 results the window keeps.
- **The routes** over the synthetic export (FRUSLightServerTests, `ReadingRouteTests`): before an import, the three documents by year in each order, a document with no date, the lines of `negotiating` in each order, an exact word that gives no line, a search with no words, and each refusal.
- **Over the owner's full 1776 export,** in a Compose project of its own, `frus-s11f` on port 8083, with this branch's image, each reading asked first with nothing kept, then again:

  | Search | Matches | Timeline | Its list | Concordance, page 1 |
  | --- | --- | --- | --- | --- |
  | `soviet` | 58,679 | 1.5 s, then 2 ms; 7,500 kept, 70 years, 25 undated | 0.07 s, 1.5 MB | 0.29 s; 1,198 lines, 12 left out at 200 |
  | `berlin crisis` | 1,623 | 0.64 s, then 2 ms; 97 years, 39 undated | 0.02 s | 0.08 s; 367 lines |
  | `"long telegram"` | 136 | 0.05 s; 51 years | 3 ms | 0.03 s; 63 lines |
  | `=containment` | 352 | 29 s; 48 years | 6 ms | 25 s; no line, 20 documents unaligned |

  A timeline of an exact word abandoned after 3 seconds stopped: the next search answered in 34 ms. The facet over the whole match the timeline first used, which nothing stops, ran 20 seconds for `=containment`.

- **In Chromium,** the desktop app's browser, on that install: the chart over `soviet` in light and dark, its pointer readout, the List mode, and the concordance at desktop and phone width.

**A review before the pull request opened.** Two reviewers, one for the server and one for the browser app and the records, each checked their own findings against the code. Every finding below held, and all are fixed here:

- **The timeline's facet over the whole match could not be stopped,** and for a match larger than what is kept it ran for its count alone: the kit arms only a search's statements for stopping, so an exact-word search abandoned over the full corpus kept the server busy for about 20 seconds. The years are now the facet over the keys of the results kept, which stop when no request waits for them, and the timeline counts nothing. The browser app's caption reads the results kept, as the Mac's rule does.
- **A search with no words,** such as a person's, counted every document of its page as giving a line, where the kit builds none and counts none as giving none. The count is now the lines' own.
- **A year's documents drew their dates in words,** two to four date formatters each for up to 7,500, which the list never shows. The rows carry their title and label alone.
- **The chart's axis read "1961.5"** between two adjacent years: its step is a whole year at least.
- **A reading being asked again was dimmed** below the contrast WCAG asks, and another search's answer stood in for the next one at full strength. A reading now keeps only the same search's last answer while the next loads, as the list keeps its last page, and is never dimmed.
- **A reading that failed was not asked again** when the same search was made again, or when an index became ready.
- **Timeline, chosen again while it was shown,** reset its List mode, which the Mac's picker does not, and the view of no dated documents carried the modes and the undated note, which the Mac's does not.
- **The long lists rendered again on any change to the screen:** up to 7,500 rows of the timeline's list, and 20,000 lines of a concordance of 100 documents. They render again only when their answer or their order changes.
- **The draft's concordance parameters** were refused as unknown, and the timeline refused a search's page fields, which `/search/inspect` takes.
- **A parity test could trap** rather than fail on an answer longer than the kit's; SPEC's departures left out the draft's `total` and the two counts the answer adds; and the install guide said "larger than the 7,500" where the caption follows the Mac's rule, at 7,500.

Refuted, among others: a timeline key the panel's sections could share, a cache that could outlive its index, a year read from a date otherwise than the facet keys it, early years cut off by the facet's ceiling, the bound read from the answer, wording unlike the Mac's, and tests that compare a value with itself. Kept, and now said: a concordance line names its document by its row's title, where the Mac's label gives the stored header.

**Records**

- `PLAN.md` and its shared copy (rev 199): the session intro and S11f's answers.
- `SPEC.md`: the Search section's readings, and the API's two paths and their departures from the draft.
- `INSTALL.md`: Reading, the timeline and the concordance, the API, and the memory a timeline's kept results take.
- `COORDINATION.md`: §1's use of the kit for the readings.
- The README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** after the review's fixes: all 2,066 tests pass, up from 2,054, with the one named skip. FRUSParityTests runs 116, up from 111, and FRUSLightServerTests 108, up from 101; the other targets are unchanged, FRUSCoreKitTests at 1,147.
- **The browser app:** typecheck and lint are clean, and 85 unit tests pass in 15 files, up from 68 in 14.
- **`scripts/compose-smoke --e2e`** on this branch's image, `frus-light:s11f`, built locally: passes, with 20 browser tests on Chromium, up from 18. The two new ones use the timeline's chart, its table and its list, and the concordance in two orders and over an exact word, each by keyboard, open a document from each and come Back to it as it was, and run axe on each. It finds nothing.

**Notes**

- **An exact-word search's readings are slow over the full corpus,** 25 to 30 seconds each, as its count and its page are, and the concordance fetches its page again where `/search` fetched it: the speed of exact-word search remains before a release.
- **The `frus-s11f` install** on port 8083, in `~/Library/Caches/frus-s11f/compose`, serves the full 1776 export from this branch's image, for the owner to try. `docker compose down --volumes` in that folder removes it and its 2.9 GB volume. The owner's install on 8080, S10's on 8081 and S12c's on 8082 were left as they were.

**Next:** Browse's own-text rows and the speed of exact-word search remain before a release. **S12d** follows once the app's repository tags `version-1.0` (build 1861), moving the pin on from `af41efa4`.

## Session 12e: pin move past FRUS-Explorer#1784, the page-map landing

23 October 2026 · branch `claude/determined-babbage-3d30b2` · upstream `af41efa4`

The pin moves from `f0479037` (`build-51`) to `af41efa4`, the owner's merge of [FRUS-Explorer#1784](https://github.com/joshbotts/FRUS-Explorer/pull/1784) the same day, and the server serves the landing 1.0 gives a page link into a volume the device does not hold (#1778). S12c's log offered this pin move of its own, under rule 5, so that the landing need not wait for `version-1.0` and S12d.

**What the move brought**

- **One commit.** `FRUSCoreKit/TEI/FRUSURLScheme.swift` gains `WholeVolumeLink` and `PageLink`, public and `Sendable`, from the app's `FRUSURLSchemeHandler.swift`, and `ReaderLinkTests`' three tests of them leave the app-only block, so FRUSCoreKitTests runs 1,147, up from 1,144. The rest is the app's records.
- **No repair.** The package builds with no warning, every kit suite passes, and the only skip is the named one. The build (1.0, 1776), the index version (71), the export's schema, the kit folders, `Package.swift`, the app's source folders and CI's allow-list are all unchanged, so `Compatibility.swift` and the install guide's versions stand.

**The landing**

- **The API.** The link route's `.page` case asks `PageLink.destination(page:volumeId:citing:onDevice:store:map:)`, as both of the app's readers ask it, with:
  - `onDevice`: whether the served index holds the volume, since the page ranges it reads are that index's;
  - `store`: the served index's `PageRangeStore`, opened immutably since S9c;
  - `map`: the bundled `cited-page-map.json`, decoded at start as the kit's `CitedPageMap` (`ServerResources.citedPages`), since the kit's own provider, `IndexingResources.citedPages`, is internal. A map that will not decode stops the server at start, naming the file, as the broken-refs index does.

  A `.document` lands as a cross-reference does. A `.volume` gives `volumeId`, `wholeVolumeLink` and `url`, as a reference to a whole volume does. No destination, for a page of a volume the index holds that neither the page ranges nor the map names, leaves the answer as it was.
- **A link that opens a volume** now carries `wholeVolumeLink`, where the kit's `WholeVolumeLink` sends it: `browse` for a volume the catalogue holds, `web` for any other, whose page is `url`. The browser app follows it, where it used to decide from the catalogue entry itself.
- **The browser app.** A page link to a document opens it as a cross-reference does; in a volume without its TEI here, the notice offers the document's page on history.state.gov. A page link to the volume opens the volume's page in Browse, which says first, for instance, "You followed a link to page 859 of this volume, which isn’t on this server.": the app's `FollowedPageLink.notice`, a localized string that stays app code, made the server's. For a volume whose TEI is here and which the server has not indexed, it ends "which this server hasn’t indexed".
  - The page is kept in that visit's history entry: Back and Forward to it, and a reload, name it again, and a visit by any other route does not.
  - The reader's old notice for a page of a volume the server has not indexed ("Page N is in …, which this server hasn’t indexed") is gone, since such a page now always leads somewhere.
- **Over the fixtures,** the 31 links into the 6 volumes the server does not hold go where the app's readers send them: 19 to the document the map names, 17 of which the index stores against it under rule C (frus1894Nicaragua d15's page 469 of frus1889 is d173), and 12 to the volume in Browse. Within the three fixture volumes, the parity test's 897 links to their pages land as before, 885 on a document: the map names nothing there that the page ranges miss.

**The golden files**, remade by `scripts/make-golden --export /Users/Shared/frus-index-build1776-golden.sqlite` under the app's `Scripts/heavy.sh` lock: the owner's 1776 three-volume export, reused on the owner's word, since `af41efa4` keeps build 1776 and changes no file on the indexing path.

- The 393 rows' HTML is byte for byte as before; the render's manifest, the expressions and the results change only in `sourceDigest` and `upstreamCommit`.
- The index summary's gating section, its 36 digests, 7 checks and volumes, is unchanged. Beside its provenance, only its information section's timings moved, which record how long this run took to hash each table.
- `frus-parity check-golden` passes.

**Tests**

- `ReaderLinkParityTests`: `everyPageLinkIntoAnotherVolumeIsWhereTheIndexStoresIt` holds each of the 31 links to `PageLink`'s answer with the volume not on the device, and asserts the 19, the 17 and the 12. `everyPageLinkLandsWhereTheAppsStorePlacesIt` asks `PageLink` with the app's own store as the device's page index, and no page of a volume on the device opens the volume.
- `ReaderLinkRouteTests`: a page the synthetic index lacks and the map names (frus1961-63v06's page 3, d4); Volume XIV's page 387, now d137; its page 859, which opens the volume in Browse; a page of the microfiche supplement, which opens on history.state.gov; a page before any import, which opens its volume; and `wholeVolumeLink` on each reference to a whole volume.
- `ResourcesTests`: the page map is decoded at start, and one that will not decode is refused, by name.
- The browser app: a unit test follows a page link into Browse and reads the line, in both of its wordings, on that visit alone. The browser suite's `page-map-landing.spec.ts` follows Nicaragua d15's link by keyboard to d173's notice, and d42's link to Volume XIV's page in Browse, with Back, Forward and a later visit from the catalogue, running axe on each. `browse-link-card.spec.ts`'s page test now shows a page nothing places, since d21's link to page 387 of Volume XIV lands on d137.

**Records**

- `PLAN.md` and its shared copy (rev 195): the session intro, the flowchart, S12e's row, S12d's row (from `af41efa4`, without the landing), the golden-files checkpoint, the risk row's counts and S12e's answers.
- `SPEC.md`: the reader's links, the API's answers for a page and a whole volume, the line a volume's page shows, and what the bundled page map serves.
- `INSTALL.md`: the page-reference bullet.
- `COORDINATION.md`: the pin; §1's use of the kit; §2's paragraph on #1784, which it lacked, and on this move; §5's list; and §6's exports, which now name S12b's of 22 October.
- `docs/prep/README.md`: the pin, and the landing served. The README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through CI's Build and Test steps: all 2,054 tests pass, up from 2,050, with the one named skip. FRUSCoreKitTests runs 1,147 (from 1,144) and FRUSLightServerTests 101 (from 100); the other targets are unchanged, FRUSParityTests at 111. Against the remade golden files the run printed:
  - "check 2 passes: 36 digests and 7 checks are the Mac's";
  - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups", and the same through the API;
  - "check 4 through the page: 393 of 393 rows identical".
- **The browser app:** typecheck and lint are clean, and 68 unit tests pass in 14 files, up from 67.
- **`scripts/compose-smoke --e2e`** on this branch's image, `frus-light:s12e`, built locally: passes, with 18 browser tests on Chromium, up from 16, and axe finds nothing.

**Notes**

- **Chromium takes a navigation to the address already shown for a reload,** which keeps the history entry's state, so `page.goto` of Browse's own address names the followed page again. The browser test's later visit comes from the catalogue.
- **Builds in a new worktree:** the Linux build reused S12c's `.build/linux` through an APFS clone (`cp -c`), so the package and its tests built in 68 seconds; `make-golden`'s two native tools built from empty, `mac-golden` in about 3½ minutes and `frus-parity` in 34 seconds.

**Next: S11f,** the timeline and concordance readings. **S12d** follows once the app's repository tags `version-1.0` (build 1861), moving the pin on from `af41efa4`.

## Session 12c: what FRUS Explorer 1.0 changed, over the API and in the browser app

23 October 2026 · branch `claude/s12c-what-1-0-changed-64c4b9` · upstream `f0479037` (tag `build-51`), unchanged

The S12 plan's third row: what 1.0 changed that the web edition serves, each as the app shows it. Three features are served here, the rows 1.0's index changed are checked through the API and the reader's links, and the one piece that is app code, where a page link into a volume the server does not hold goes, is [FRUS-Explorer#1784](https://github.com/joshbotts/FRUS-Explorer/pull/1784), which the owner merged the same day.

**A result's date** (#1746)

- **The API:** each search row adds the kit's `dateISOMax` and `datePrecision` (`day`, `month` or `year`), and `drawnDate`, the words the kit's `SearchResultDate` gives them: "July 16, 1945", "August 21, 1945 – January 22, 1946", "July 1945", "1862". The server passes US English, the language of the browser app's words, where the app's `SearchResult.drawnDate` takes the device's locale.
- **The browser app:** a row draws its dateline, or for a row that prints none the drawn date, as the Mac's window draws `result.dateline ?? result.drawnDate`.
- **On the full 1776 export,** a section's row is dated by the documents it holds: frus1862's ch23, "Guatemala and Salvador.", draws "July 29, 1862 – September 15, 1862", and frus1865p3's ch14, "Mexico.", "May 4, 1861 – June 9, 1866". The export holds 7,780 rows that are not documents, 5,707 of them dated, 4,245 by a span; build 50's held 4,182, 951 and 165.

**The reader's Reading Width** (#1699)

- **The API:** the page takes `readingWidth`, `narrow`, `standard` or `wide`, beside `textSize` and `colorScheme`, and passes the step's measure to `ReaderPage.build(measure:)`: 70, 87 or 120ch, the steps the app's Settings ▸ Display offers on an iPad and the Mac, Standard by default. Until now the server passed none, so every page had the kit's 70ch.
- **The ladder is app code** (`ReadingWidth.measure(on:)`), which the kit leaves to its host, so the server mirrors its three numbers. `ReaderPageParityTests` reads the rungs, and the setting's default, from the app's source at the pin: a pin move that changes one fails there.
- **The browser app:** Reading Width, a select beside Text Size, with the app's Narrow, Standard and Wide, kept in the browser as Text Size is. A page loaded again for another width leaves focus on the control, as Text Size and Appearance do.
- **In Chromium,** measured on the Long Telegram (frus1946v06/d475) at Medium text, the app's own test document: a mean 69.5, 91.2 and 133 characters a full line at the three steps, where the app's WebKit gives 77, 100 and 145. The install guide gives both.

**A search whose client goes stops** (#1698)

- **What S10 found:** a request its client abandoned ran on; after the timeouts the server went on computing those searches.
- **The server:** Hummingbird allows half-closure and cancels nothing when a client goes. Each connection's pipeline now holds a handler that notices the client's side closing, the input closed or the connection gone, and the API's request context keeps its connection. `/search` and `/search/inspect` run their work while the client is connected: when it closes, the work is cancelled, and the kit's one progress handler (`SearchStatementStop`) stops the statement at its next call. The problem middleware logs it at debug level and answers 499, which reaches no one.
- **The kept results:** the cache of what a served index computed lately makes a waiting request leave at once when it is cancelled. The results a date order keeps are stopped once no request waits for them, as the Mac stops a replaced search; a facet section runs to its end and is kept, since nothing stops the kit's facet pass on the Mac either.
- **The browser app** already abandoned a search it replaced: TanStack Query aborts a fetch whose query loses its last observer, and the browser then closes the connection. A unit test pins it.
- **On the full 1776 export,** an exact-word search (`=Soviet`) whose client gave up after a few seconds: with S12b's image the server held a core at 100% for at least 25 seconds after; with this branch's, it was idle within about a second, and its log said "GET /api/v1/search stopped: the client closed its connection before the answer".
- **End to end in Chromium,** the desktop app's browser, on the same install: an `=Soviet` search from the box, then another typed over it while the first ran. The server logged the first one's stop and was idle by the next sample, and the second answered, 722 documents.

**The pages and rows 1.0's index changed** (#1746, #1747)

- **A section's row dated by its documents** comes through the API with its span and its words, as above.
- **Cross-volume page references under rule C:** the fixture pages hold 31 links to a printed page of another volume, into 6 volumes. Through the API each is that page, which this server, holding only the three fixture volumes, cannot place. The bundled page map names a document for 19 of them, and 1.0's index stores 17 of those against it, frus1894Nicaragua d15's page 469 of frus1889 becoming d173 among them; the rest the index leaves on the page. A new parity test asserts each link's answer and those counts.
- **The landing** the app gives such a link since #1778 is `PageLink`, app code until #1784; the web edition serves it from the pin move past `af41efa4`. `docs/prep/README.md` says how.

**The upstream pull request:** [FRUS-Explorer#1784](https://github.com/joshbotts/FRUS-Explorer/pull/1784), "Where a link to a whole volume or a printed page goes is FRUSCoreKit's, so FRUS Explorer Light can follow one as both readers do", labelled `Mac`, with "Mac verification requested".

- **The change:** `WholeVolumeLink` and `PageLink` move, unchanged but for `public` and `Sendable`, from the app's `FRUSURLSchemeHandler.swift` to the end of the kit's `TEI/FRUSURLScheme.swift`; `FollowedPageLink` stays. `ReaderLinkTests`' three tests of them leave the app-only block. One editable-content block is re-pointed, and `CLAUDE.md` and the app's plan record it.
- **Run here, from a clone at a real path, each heavy job under the app's lock, beside `v2` built and run the same way:**
  - `FRUSExplorerMac`, Debug, clean, unsigned: built, with `v2`'s five warning lines. The two debug dylibs hold the same 249,388 symbols, 245,175 defined: no symbol changes;
  - iOS 27.0 on an iPhone 17: a clean `build-for-testing`, with `v2`'s 7 warning lines; the full unit target, 7,606 tests in 900 suites, with the 8 Keychain issues an unsigned build has, as on `v2`, and the same 17 tests and 2 suites skipped;
  - `swift build --target FRUSCoreKit`, and `swift test`: 38 runs, 3,033 tests, all passing, none skipped, against 3,030 on `v2`; `FRUSCoreKitTests` 1,147, up from 1,144;
  - `CodingStandardsAuditTests` again at the records commit: 63 passed;
  - Linux: this package at `main` with the branch over its submodule: FRUSCoreKitTests 1,147, every other target passing but the parity suites, whose 13 issues are all golden-file staleness.
- **Merged** by the owner on 23 October as `af41efa4`, a squash of the branch's two commits whose tree is the branch's head byte for byte, now `v2`'s head; no Mac check results were posted on it. The pin stays at `f0479037` here: it moves only in a pull request of its own (rule 5).

**A review before the pull request opened.** Three reviewers, one for the server, one for the browser app and the records, and one for #1784, each checked their own findings against the code. None found a correctness defect. Every finding below held, and all are fixed here but #1784's records:

- **Turning the date order round while the kept results were computed** would have started them again. The abandoned request left the computation with no one waiting, so it was stopped, and the replacing request, for the same search, came too late: its count waited behind that computation's statement. A request now joins the kept results before it counts, and a computation no one waits for runs on for 250 ms before it is stopped, so the replacing request joins it. A test holds the grace.
- **No test failed if the server lost its watch:** the live test built an application of its own. Both now build it with `apiApplication`.
- **Two tests waited on sleeps.** The cache's and the closure's now wait for their waiters to register, and the closure's also covers a waiter cancelled while it waits.
- **A request whose client had already gone** started its work before stopping it; it now stops at once. A connection reset outright before its route asks has no pipeline left and is not watched, which the code now says; a browser that abandons a request closes with a FIN, which the half-closed pipeline keeps.
- **The browser suite's measure** read the frame by its URL and could throw while the frame was between pages; it reads the frame shown, through a locator that waits for its column. The abandoned-search test held the first search for a fixed two seconds; it now holds it until the page has abandoned it.
- **The install guide** gave Chromium's line lengths without saying so; it gives the app's too. SPEC named the app's wrong route for the measure, and its focus sentence left out Reading Width.
- **The rule-C test** printed its 19 and 17 and asserted neither; it asserts both.
- **#1784's records** say "unchanged and public" where the types are also `Sendable`, and `FRUSURLScheme`'s own history logs no move. It had merged by then, so these wait for the next web-authored upstream pull request (Notes).
- A doc comment the new parity test had pushed above the wrong test is back on its own.

Refuted, among others: a double resume or a lost wakeup in the closure or the cache, a close the pipeline would not deliver, a facet section stopped while it was still wanted, an abort test that could pass for the wrong reason, and wording unlike the Mac's.

**Records**

- `PLAN.md` and its shared copy (rev 188): the session intro, S12d's row, Mac check 7, done once #1784 merged, the risk row and S12c's answers. The file's flowchart gains Mac check 7; the shared copy's diagram covers phase 1's sessions only, as before.
- `SPEC.md`: the reader's measure, the search rows' dates, a replaced search, and the API's `readingWidth` and date fields.
- `INSTALL.md`: dates in the results, a replaced search, Reading Width and the API's `readingWidth` and `drawnDate`.
- `COORDINATION.md`: §1's use of the kit at the 1.0 pin with the Reading Width mirror, and §5's list of web-authored pull requests, with #1784.
- `docs/prep/README.md`: how to serve the landing after #1784 merges. The README's Status and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through CI's Test step, after the review's fixes: all 2,050 tests pass, up from 2,037, with the one named skip. FRUSLightServerTests runs 100, up from 91, and FRUSParityTests 111, up from 107; the other targets are unchanged.
- **The browser app:** typecheck and lint are clean, and 67 unit tests pass in 14 files, up from 64 in 13.
- **`scripts/compose-smoke --e2e`** on this branch's image, built again after the review's fixes: passes, with 16 browser tests on Chromium, up from 13. The new ones draw the rows' dates, use the Reading Width from the keyboard with its measure read from the page, and replace a search under way, and run axe after each; the note-focus test also changes the Reading Width. It finds nothing.

**Notes**

- **The S12b install** on port 8082, `frus-s12b` in `~/Library/Caches/frus-s12b/compose`, now runs this branch's image, `frus-light:s12c`, over the full 1776 export, for the owner to try. `docker compose down --volumes` in that folder removes it and its 2.9 GB volume. S10's install on 8081 and the owner's on 8080 were left as they were.
- **A client that half-closes** its connection while it waits for an answer is taken to have gone, as Go's server takes it. No browser does; `nc -N` would.
- **#1784's records, for the next web-authored upstream pull request:** the moved types' version-history lines, the handler's 1.10, `CLAUDE.md` and the amendment log say "unchanged and public" and leave out `Sendable`, which the pull request's body and the app's session entry name; and `FRUSURLScheme`'s own history logs no 1.4 for the move. A review found them after the merge, with nothing else; none changes what the code does.
- The upstream clone, its build folders and a scratch worktree of this repository are under `~/Library/Caches/frus-s12c`.

**Next: S11f,** the timeline and concordance readings, since the app has not tagged `version-1.0`. **S12d** follows once it does, and serves the page-map landing too, since #1784 merged first; a pin move of its own to `af41efa4` can serve the landing sooner, if the owner wants it before the tag.

## Session 12b: pin move to `build-51`, FRUS Explorer 1.0 (build 1776)

22 October 2026 · branch `claude/s12b-pin-build51-544354` · upstream `f0479037` (tag `build-51`)

The pin moves from `757c6d29` (build 50, index version 69) to `f0479037`, the commit the owner tagged `build-51`: FRUS Explorer 1.0, build 1776, the TestFlight build, at index version 71. It is 85 commits on, with the 18 pull requests on shared code or bundled data that [issue #37](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/37) lists. The owner made both 1776 exports on 22 October: three volumes for the golden files, and the full corpus.

**What the move brought**

- **Index version 71** (#1746, 70; #1747, 71). `IndexCompatibility.supportedIndexVersion` follows the pin, so the server now refuses build 50's exports, naming both versions. The FTS generation (4) and the JSON export's `formatVersion` (6) are unchanged.
- **A fifth indexing resource,** `cited-page-map.json` (#1747), which `IndexingResources.indexResourceNames` now names. `ServerResources.requiredFiles` follows that list, so the server will not start without it, and the image already copies the whole resources folder.
- **No repair.** Every kit builds and passes on Linux with no new skip, as issue #37's dry run found, and no kit folder, `Package.swift` setting or app source folder changed. The web edition's own code changed only in tests, a doc comment, and the facts below.
- **The export's schema is unchanged.** Both 1776 exports hold `export-v69-schema.sql`'s 74 statements, in its order, and nothing else but FTS5's shadow tables, which the fixture leaves out by design. `setupDatabase(_:)` is the same text at the new pin, lines 7680–8335. So the fixture stands, under its name, and `IndexSchema.swift`'s list with it.
- **No pinned reader head to re-take** (#1699). No web test pins `ReaderPage`'s head: the parity tests compare the page with the kit's own build of it. The server builds the page with `ReaderMeasure`'s default, `.classic`, until S12c brings Reading Width.

**The golden files**, remade by `scripts/make-golden --export /Users/Shared/frus-index-build1776-golden.sqlite`, run under the app's `Scripts/heavy.sh` lock:

- **The render:** 393 rows, not 392. The new one is frus1969-76ve09p1's `notes`, its Note on U.S. Covert Actions, one of the prose rows the index left out until #1746 (`promotableQuasiDocumentKinds`). The other 392 rows' HTML is byte for byte as before, and the manifest changed only in provenance and that row.
- **The expressions:** 15 of the 482 queries compile differently, all by parser 6.8 (#1770), which trims a mark from a term's end: `"europe,"` is now `"europe"`, `"u.s.s.r."` `"u.s.s.r"`, `"-berlin"` `"berlin"`, `"‘test"` `"test"`, and so on. 43 are refused, as before.
- **The index summary:** its 7 checks and the schema's digest are unchanged, and 18 of its 36 gating digests moved, each with a pull request:
  - #1746's notes row: `document_cache` and its sequence, `document_dates`, `document_revisions` (also every row at 71), both FTS tables' `docsize` and `averages`, the three vocabularies, and `page_ranges` and its sequence (pages xxii–xxvi);
  - `cross_references` and its sequence, 208 rows to 221: the notes row's 13 references (#1746), and 17 references to a printed page of another volume that now name the document on it, `frus1889`'s `pg_469` becoming `d173` and the like (#1747, rule C through the page map);
  - `volume_structures`: each of the 28 sections records `leadsWithSubsections`, false for every one (#1746);
  - `volume_sources`: frus1969-76ve09p1's "POL Libya" row is keyed `POL LIBYA`, a file with no subject number that leads its row (#1746);
  - `person_rollup`: 75 of the 121 rollups lose a VIAF id, since build 51 takes no Wikidata or VIAF link from the name-authority overlay (#1710).
- **The results:** every query's score bits moved, since BM25 reads the whole index and the index has a row more. 41 counts rose by one, and in each the notes row matches the query's compiled expression; other changes in the top 50 are reorders by those scores. Ties past the 50th place fell from 12 queries to 7.
- `frus-parity check-golden` passes.

**The tests that named build 50's facts**

- `APITests.theSubmodulesDataFilesLoad`: 6 required files, the last `cited-page-map.json`. `IndexResourcesTests` lists the five index files and decodes the page map, built for the pin's index version.
- `SummarizerTests`: the summary's build is 1776. The parity export now stamps the pinned app's version as well as its build, both read from `project.yml`.
- `ServedAPIParityTests`: the fixture index holds 393 documents.
- **The snippet rule** (#1736): `aSnippetMarksAMatchOnlyInTheProse`, new, serves a synthetic export whose body opens with its heading and dateline. A word matched in the prose is marked; one matched only in the heading or dateline gives the prose's opening with nothing marked; one only in a heading the body does not repeat gives the heading again. The existing test that every row has `<b>` still holds, since both of its rows match in their prose. `SearchItem`'s doc comment says so.

**Release tags**

- **`scripts/release-tag`** prints `<version>-<build>` from the pinned `project.yml`'s `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`: `1.0-1776` here, and `0.2-50` at the old pin. It fails when the app's targets disagree, when either is missing, or when either is not numbers and dots.
- **`image.yml`** reads it in each build job, so every pull request that touches the image checks it, and the promote job, after the smoke test on both architectures, moves the release tag with `edge`: `:1.0-1776` follows `main` while the pin holds build 1776, and stays on the last such build once the pin moves on. Sessions never publish (rule 7).
- `docs/INSTALL.md` and SPEC name the release tags.

**Checks 3–5 on the full 1776 export**, as S10 ran them:

- **The install:** a Compose project of its own, `frus-s12b`, with `compose.yaml` and a `.env` naming the port, the TEI folder and the image. The port is 8082, since S10's install still holds 8081 and the owner's 8080, and both were left as they were. The image is this branch's, `frus-light:s12b`, built locally from the code of `5c59c6b`, since sessions never publish. The TEI folder is the owner's clone of HistoryAtState/frus, read-only, at `6170e4b32` (1.1.4), the corpus #1746 measured its rows on.
- **Check 5, import acceptance:** the full export was ready 43 seconds after the copy began, serving 321,749 documents from 553 volumes at index version 71. Read immutably, it holds no summary, note or tag and no `user_tags` row, and its `user_content` index no term. The refusal half, and `scripts/check-stripped-export`, need an export with the owner's writing from build 1776, which there is not; the refusal's code is unchanged since S10, and the server's tests refuse a synthetic export that holds writing.
- **Check 3:** `mac-golden results --any-volumes` ran the app's SearchService over a copy of the export in 31 minutes 11 seconds: 482 queries, 43 refused, 9 with ties past the 50th. `frus-parity results --api` read the same queries through the install's API: 886 requests in 37 minutes, none timing out. `frus-parity compare-results` printed "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups"; 392 queries have other score bits, which is information, as on build 50 (349).
- **Check 4:** the sample is the middle row that is not front matter in each of the 553 volumes, in index order, now drawn from the 1776 export. Five have an id other than `d` and a number, such as frus1943v06's `ch44`, an agreement, and frus1958-60v05mSupp's `gt_d10`. `mac-golden render --tei --rows` rendered them through the Mac reader's path in 1 minute 57 seconds, 5,652,473 bytes of HTML. `frus-parity render-api` fetched each one's body from the server and compared the bytes: "check 4 through the API: 553 of 553 rows identical", in 2 minutes 38 seconds. No row in this sample has a figure image; S10's had 14 in 2 rows.
- Each run took the app's `Scripts/heavy.sh` lock, one at a time, as the image build had.

**Records**

- SPEC: the compatibility contract (71 at `f0479037`, app 1.0 build 1776); the table definitions' lines; the image's tags; the bundled data, with `cited-page-map.json`, the resized citation and semantic files, 54 MB in all, and the Legal row gone; and the licensing lines: EmbeddingGemma 2 is Apache 2.0, from the `encoder-2` release, downloaded only at an admin's request, with no consent screen, since the Gemma Terms file is gone from the bundle (#1674). The shards' address names their generation, `generations/89481b18/`. The corpus figures follow 1.0: a full index holds about 322,000 documents, and the semantic map places 314,616 in 140 clusters.
- `INSTALL.md`: index version 71 and FRUS Explorer 1.0 (build 1776), the second version change, and the release tags.
- `COORDINATION.md`: the pin, the contract, the kit's test counts, the 393 rows and this move.
- `PLAN.md` and its shared copy (rev 180): S12b done, the golden-files and 1776-export checkpoints, the risk row's counts, and the release tag's rule.
- The README's Status, as #40 rewrote it, merged here from `main`: only what the move makes untrue, the gap behind 1.0 and S12b's line under Next. The prep note and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** from a clean build of this package's own targets: all 2,037 tests pass, up from 1,934 at the old pin, with the one named skip, which CI's skip check allows.
  - By target: FRUSCoreKitTests 1,144 (from 1,061), SourceNoteKitTests 321 (310), FTS5StoreTests 212 (209), FRUSParityTests 107, FRUSLightServerTests 91 (90), ManifestGeneratorTests 60, FRUSLightCoreTests 42, SemanticVectorsKitTests 40 (35), CrossRefKitTests 10, GeneratorKitTests 7, FTS5CheckTests 3.
  - Against the remade golden files the run printed:
    - "check 2 passes: 36 digests and 7 checks are the Mac's";
    - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups", and the same through the API;
    - "check 4 through the page: 393 of 393 rows identical".
- **CI** passes on this pull request, with the same counts and the one named skip. Both architectures' image builds read the release tag `1.0-1776`, and the web app's checks and the Compose smoke test with the browser suite pass.
- **On the owner's full 1776 export:** checks 3, 4 and 5's acceptance half pass, as above.

**Notes**

- **Exact-word searches are still slow** over the full corpus: the slowest requests took 57 seconds through the API, against 66 at build 50, with nothing else running. Check 12 is phase 5's.
- **The new prose rows are front matter where `<front>` prints them.** The notes row of frus1969-76ve09p1 is one (`is_front_matter` 1, no date), and the Mac's search counts it, as the server's does; Browse's own-text rows remain before a release.
- **The owner's own install** on port 8080 serves the build 50 export. Once it runs an image at this pin it refuses that export, naming both versions, until the full 1776 export is copied in.
- **The S12b install** on port 8082, `frus-s12b` in `~/Library/Caches/frus-s12b/compose`, still serves the full 1776 export from the local image. `docker compose down --volumes` in that folder removes it and its 2.9 GB volume. S10's install on 8081 was left running.

**For the owner after the merge**

- `image.yml` publishes `ghcr.io/joshbotts/frus-explorer-light:1.0-1776` beside `edge` and the commit's `sha-` tag, once the smoke test passes on both architectures.
- Your own install then needs the full 1776 export: `docker compose pull && docker compose up -d`, then `docker compose cp -L /Users/Shared/frus-index-build1776-allvols.sqlite frus:/data/import/`, as `docs/INSTALL.md` says.

**Next: S12c,** what 1.0 changed that the web edition serves: a result's date range and precision, the reader's Reading Width, a replaced search stopping its statements, and the rows 1.0's index changed, with the upstream pull request for the page-map landing. **S12d** follows once the app's repository tags `version-1.0` (build 1861).

## Session 12a: the daily watch of `v2`

22 October 2026 · branch `claude/s12a-upstream-watch-b8c058` · upstream `757c6d29`, unchanged

The owner approved the plan of [issue #37](https://github.com/joshbotts/FRUS-Explorer-Web-App/issues/37)'s revision and asked for S12a: the daily watch COORDINATION §5 gives web sessions, whose absence let 85 of the app's commits go unseen.

**The watch**

- **`.github/workflows/upstream-watch.yml`** runs daily at 06:17 UTC and from the Actions tab's Run workflow, with a ref other than `v2` and a dry run as options. It needs `contents: read` and, in its report job only, `issues: write`. It never moves the pin and never publishes.
- **`scripts/upstream-watch`** does the work, and each step also runs on a Mac:
  - `checkout` moves the submodule's working tree to `v2`'s head inside the job, never staging it;
  - `test`, in `swift:6.4-noble` with ci.yml's cache restored and this package's targets built clean, builds the package and runs each test target on its own. A build break or a kit suite's failure is the watch's finding, and fails the scheduled run. This package's own tests check the pin's facts, so they fail past it by design, and are listed by suite as information for the pin move;
  - `report` compares `v2` with the pin: the index version, the FTS generation, the JSON export's `formatVersion`, `indexResourceNames`, FRUSCoreKit's and FTS5Store's `CREATE TABLE` and `ALTER TABLE` statements (read from the sources, with Swift's interpolations kept whole), the bundled resources added, changed or removed, and the commits since the pin, whose pull-request numbers sit in code spans so they neither link here nor mention the app's pull requests;
  - `issue` keeps one issue labelled `upstream-watch`: it opens one when `v2` is past the pin and none is open, otherwise rewrites the open one's description, and comments only when `v2`'s head or the kits' result changed. When nothing is past the pin and the kits pass, it closes the issue.
- **On a pull request** that changes the watch, the workflow runs at `v2`'s head in its dry mode: it prints the issue writes, and fails on nothing `v2` does. Its jobs, `watch-selftest`, `watch-kits` and `watch-report`, are not `main`'s required checks.

**Checked**

- **A run at `v2`'s head** (`f0479037`, `build-51`), locally in `swift:6.4-noble` on arm64 and in this pull request's dry run on CI: index version 69 → 71, the FTS generation 4 and the export's `formatVersion` 6 unchanged, `cited-page-map` the sixth index resource, `cited-page-map.json` added and `gemma-terms-of-use.txt` removed among 15 resource changes, the 47 schema statements unchanged, and 85 commits. Every kit suite passes, with the counts issue #37's dry run found (FRUSCoreKitTests 1,144, SourceNoteKitTests 321, FTS5StoreTests 212 with its one allowed skip, ManifestGeneratorTests 60, SemanticVectorsKitTests 40, CrossRefKitTests 10, GeneratorKitTests 7). FRUSLightCoreTests, FRUSLightServerTests and FRUSParityTests fail where S12b expects.
- **The issue logic,** by `scripts/upstream-watch selftest` against a stub `gh`, in CI's `watch-selftest`: no issue while nothing is past the pin; one opened; a second run at the same head updates it with no comment; a new head updates the same issue with a comment; a dry run finds it and writes nothing; it closes when nothing is past the pin, and a later change opens a new one. A dry run against this repository, which has no watch issue yet, would open one.
- **The schema reader** was checked against the upstream commit that moved the index's tables into FRUSCoreKit, where it reports all 42 of that kit's statements as new.

**Records**

- `COORDINATION.md`: §1 and §3 no longer say the watch is to come, §5's row and a paragraph below its table say what it does, and §6 says what its issue is for.
- `PLAN.md`, on top of PR #38's revision, merged while this one was open, and its shared copy (rev 174): an owner checkpoint for the watch's first run, which S12a's done-when needs and only the owner can make once the workflow is on `main`. This log.

**For the owner after the merge**

- The first run: Actions → upstream-watch → Run workflow, on `main`, with `v2`. It opens the watch issue with the report above; the label is created on that run.

**Next: S12b, the pin move to build-51 (build 1776).**

## Issue #37: the plan catches up with FRUS Explorer 1.0

22 October 2026 · branch `claude/issue-37-dev-plan-revision-846914` · upstream `757c6d29`, unchanged

The owner asked for issue #37 to be reviewed, and the plan revised to catch up with the app before feature work goes on. The issue, posted from a session in the app's repository, finds `v2` at `build-51` (`f0479037`, build 1776, the 1.0 TestFlight build), 85 commits past the pin, at index version 71. No web session had seen those commits: the daily watch COORDINATION §5 assigns to web sessions was never added. This session changes records only.

**Checked against the app's repository**

- Each fact the next pin move depends on holds at `build-51`:
  - `currentDateIndexVersion` is 71;
  - `cited-page-map.json` is added to the bundled data and `gemma-terms-of-use.txt` removed, with the other changed resources the issue lists;
  - 85 commits separate `build-51` from the pin.
- Each of the 17 pull requests' lines for the web edition was read. #1778 changes no kit code, but its page-map landing is app code the web reader would need, so S12c moves it into the kit.
- **A dry run at `build-51`** built and tested this package on Linux, then restored the pin. The build needs no repair, and every kit suite passes, with only the skip CI already allows. The web edition's own tests fail where a pin move expects: the index version, the sixth resource file, stale golden files, 61 expressions under parser 6.8, and a 393rd fixture row. `docs/prep/README.md` records it, under "The 1.0 pin move".

**The plan**

- **S11f waits.** Four rows come first:
  - S12a, the daily watch of `v2`, which needs no Mac and no export;
  - S12b, the pin move to `build-51` (1.0, build 1776), for an image tagged `:1.0-1776`;
  - S12c, what 1.0 changed that the web edition serves: result dates and their precision, the reader's Reading Width, a replaced search stopping its statements, and the rows 1.0's index changed. Its upstream pull request moves #1778's page-map landing into the kit;
  - S12d, the short pin move to `version-1.0` (build 1861) once it is tagged, for `:1.0-1861`.
- **Owner checkpoints:** a 1776 export and an 1861 export, each a three-volume one for the golden files and a full one for the owner's install, and Mac check 7.
- **The upstream-churn risk** now records the gap, and the watch as its mitigation.
- **The S12 answers** say which 1.0 changes come with the pin, which wait for phases 2–4, and what remains before a release. The owner answered the one question it left open: a release image is tagged with the app's version and build, `:1.0-1776` and `:1.0-1861`, joined by a hyphen since a tag cannot hold the slash asked for, and asked for both to be published, so the pin lands at `build-51` before `version-1.0`.

**Records**

- `PLAN.md` and its shared copy (rev 173): the S12 rows, the flowchart, the checkpoints, the risk row and the S12 answers.
- `COORDINATION.md`: the gap, and S12a as the watch's author.
- `SPEC.md`: the release tags.
- `docs/prep/README.md`: the dry run. This log.

**Results**

- No code changed. CI runs as it does on any pull request, at the pin.

**Next: S12a,** the daily watch of the app's `v2`. S12b can start beside it at `build-51`: the owner made both 1776 exports the same evening, the three-volume one (393 rows) and the full one (553 volumes), each stamped build 1776 at index version 71.

## Session 11e: the Query Inspector, and the date order

14 October 2026 · branch `claude/s11e-search-readings` · upstream `757c6d29`, unchanged

The owner merged #35 and asked for S11e. A reader mapped the Mac's search window: its Query Inspector strip and its view of a search that found nothing, the sort bar, and the timeline and concordance readings with the captions that name what each counted. The four were again too many for one reviewable pull request, as S11d's had been, so this one brings the Query Inspector and the date order, and S11f brings the timeline and concordance readings.

**The API**

- **`/search/inspect`** keeps `parse` and `search`, the expression records check 3 reads, and adds `inspection` while an index is served: the kit's `QueryInspection`, from the Query Inspector's cheap pass, `QueryInspector.inspect(parameters:indexedVolumeCount:)`, out of the volumes the index holds. It runs no search.
  - Each term comes with its tags, its index form, its corpus counts from `fts5vocab`, and the gates the strip reads.
  - `scopedCounts=true` adds each term's count within the filters, and `emptyConjuncts=true` names the terms that match nothing on their own, the kit's two expensive passes. Each runs one count a term, and is refused with `INDEX_NOT_READY` until an index is served.
  - A query of more than 64 terms is compiled but not looked up, and either pass is refused for it as `TOO_MANY_TERMS`: each term costs the index statements of its own, run one after another on the connection every search shares.
- **`/search` takes `sort`**, a `SearchSortOrder`. By relevance a page is the kit's page of the match, as before. In either order of the date it is cut from the 7,500 results the search keeps, sorted whole by `SearchSortOrder.sorted(_:)`, as both of the app's view models sort what they keep. Every list names its order and offers the three by the kit's labels.
- **What a served index computed lately** is one type now, `RecentComputations`, which keeps the facets' 16 sections and the results of the last 2 searches ordered by date, so a search's other pages fetch them once.

**The browser app**

- **The Query Inspector's strip**, under the filters, follows the box's text as it is typed, before the search is made, as the Mac's does: the text trimmed and the filters, asked for once typing pauses for 300 ms. It shows MATCH and the expression, with the caption for one narrower than typed, or the one line that says why there is none.
- **Its term detail**, behind the Mac's ▾ (**Show term detail**), lists each term with its tags (EXCLUDED, EXACT, ADVANCED), its counts and the stem that widens it, then each part left out (NOT APPLIED), and the denominator. **Count each term in scope…** counts each within the filters, and the counts go when the text or a filter changes.
- **A search that found nothing** says why in the Mac's words, from each of its terms searched alone under its filters: "formosa matches no document in your current scope", or that the combination is what matches nothing.
- **Sort** offers Relevance, Date ↑ and Date ↓, which start the order at its first page, and the order outlasts a new search and a facet's narrowing, as the Mac's does.
- **A match larger than what a search keeps** says so above the results on every page, in the Mac's words: "Showing 7,500 of 20,000 matches", and how to narrow it. It replaces the web's own note on the last page.
- **The facets' "The top three hold" caption** is no longer given of such a match, as the Mac's panel withholds it: a figure over the most relevant 7,500 is partly a statement about the ranking.

**Checked**

- **Through the API, beside the kit,** over the fixture index imported as an export (FRUSParityTests):
  - every one of the 482 parity queries is inspected as the kit inspects it, with its scoped counts and the terms that match nothing; between them they reach every state the inspector reports, from an expression that differs between documents and the reader's writing to a malformed NEAR;
  - every page of a sixth of the queries, in each order of the date, in pages of 7 and of 100, joins up to the kit's order of what the search keeps, undated documents and documents of one day among them;
  - the browser app's line for a refused query names the parser's limit on nesting, which the test reads from FTS5Store itself.
- **The Mac's strings** are the browser app's wherever a control is the same, with "this device" and "you have indexed" made this server.

**A review before the pull request opened.** Two reviewers, one for the server and one for the browser app and the records, each checked their own findings against the code. Thirteen held. Eleven are fixed, one is kept and now said, and one is left as the Mac leaves it:

- **The view of a search that found nothing** could run over the last search's page while the next loaded, and blame a search that had matches. It waits for the search shown to be the one made, as the Mac's view waits.
- **The expensive passes could run unasked:** counts came back when the text returned to what was counted, and a window regaining focus asked again. They run only when asked, or when a new index is served.
- **A failure to ask again** replaced a good answer with the generic line, and making the same search again did not ask again.
- **The strip showed the last query's expression** while the next was asked for after the box was emptied.
- **The date order over a larger match** read as the oldest of all of it. The Mac's notice now says what the search keeps, and the install guide qualifies the order.
- **The figure per document** rounded a tie away from zero, where the Mac's formatter rounds half to even.
- **Every keystroke rendered the whole screen.** The text is held by the search box, the filters and the strip.
- **Pasted text could tie up the server:** the inspector looked up every term of a query of any length. It looks up 64 at most.
- **A test could not tell** whether a scoped count read the filters, and the records said "waits" of a refusal, named a control that shows only ▾, and claimed more of the cache than it does.
- **Kept, and now said in SPEC:** `/search/inspect` takes a search's page and order too, which change nothing it says, so a search's address can be inspected as it stands.
- **Left as the Mac leaves it:** a search ordered by date that no request waits for any more still fetches what it keeps, to its end. The cache now keeps 2 such searches, not 4, and the install guide says what they hold.

Refuted, among others: a string unlike the Mac's; inspector queries that could collide or never refresh; cache keys that could join two searches; the denominator, which is the count the Mac's `indexedVolumeIds` holds; and parity tests that could pass while comparing a value with itself.

**Records**

- `PLAN.md` and its shared copy (rev 155): S11e's row, S11f's, and the S11 answers.
- `SPEC.md`: the Search section, and the API's `sort` and `/search/inspect`.
- `INSTALL.md`: Sort, the Query Inspector, the date order's limit and its memory. The README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through the Test step's own script: all 1,934 tests pass, up from 1,928, with the one named skip. FRUSParityTests runs 107, up from 104, and FRUSLightServerTests 90, up from 87; the other targets are unchanged.
- **The browser app:** typecheck and lint are clean, and 64 unit tests pass in 13 files, up from 50 in 12.
- **`scripts/compose-smoke --e2e`:** passes, with 13 browser tests on Chromium, up from 11. The two new ones use the Query Inspector as it is typed, its counts in scope, a search that found nothing, and both orders of the date, and run axe with the term detail open, over the view of a search that found nothing, and in the date order. It finds nothing.

**Notes**

- **A search ordered by date** fetches the 7,500 results it keeps, with their snippets, on its first page, as the Mac's window fetches them for every search. Over the whole corpus that costs what a Mac search costs; check 12 has not timed it here, over three fixture volumes.
- **The Mac's caption for expressions that differ** between documents and the reader's own writing has no place in the browser app, which sends no scope that could make them differ.

**Next: S11f,** the timeline and concordance readings over the API and in the browser app, each naming the set it counted. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11d: the facets, with include, exclude and Apply

14 October 2026 · branch `claude/s11d-search-features` · upstream `757c6d29`, unchanged

The owner merged #33 and #34 and asked for S11d. Three readers mapped the kit's public search code, the Mac's search window and what the web edition had. The search features were then too many for one reviewable pull request, as the S11c features had been, so this one brings the facets, and S11e brings the Query Inspector, the date order and the timeline and concordance readings.

**The API**

- **`/search/facets`** computes one section of a search's whole match: years, volumes, people, document type, provenance or subjects. It uses the kit's `SearchService.resultSetFacets(parameters:request:documentKeys:)`, the route the app's panel takes, as the panel computes a section when it is opened.
  - The rows come as the kit's `FacetPaging` cuts them, by a sort, page size, page and filter, each the kit's standard for the section unless given.
  - Beside them: the section's bound, the kit's titles for its sorts and page sizes, and what the panel says: the undated count, the three largest volumes' share, and the provenance and subject coverage.
- **A row that narrows on a click** (people, document type, subjects) carries its narrowing: the query fields the kit's `FacetNarrowing` changes, each with its values, or null for one it leaves out. The browser app makes that change to the search it shows, so it never needs to know which fields a narrowing touches.
- **`/search/facets/selection`** resolves a staged selection of years or volumes over the section's whole list, as `FacetSelection` and `FacetSelectionApplier` resolve the Mac's Apply. An exclusion alone means every row but those.
- **Each served index keeps the 16 sections it computed last,** by the search and the section. A section's other pages, sorts and filters, and its Apply, cost no second computation, as on the Mac, which computes a section once for a search and cuts it as it is shown. A new import opens a new index, which starts with none.
- **The search request** has one decoder for every search endpoint, and four more fields: a person's rollup and name, and a subject's place and durable name, the fields `FacetNarrowing` sets. Its new encoder writes a search back as the fields the decoder reads, for the narrowings. The draft's `facets` parameter is refused with a pointer to the new paths.

**The browser app**

- **The panel** opens from a Facets toggle beside the count, and stays open across searches (`panel=facets`). Its six sections are closed until opened, and each is fetched when it is, in the Mac's wording: titles, rows, sort and page-size menus, the filter field over 100 rows, the page footer, and each caption.
- **Years and volumes** stage rows: a click cycles one through not selected, included and excluded, in the order of the kit's `FacetRowState`, and the strip says "2 included · 1 excluded" with Clear and Apply. The resolution is the server's, so it is the kit's.
- **People, document type and subjects** narrow on a click, and focus returns to the section's heading. Provenance rows only describe, as on the Mac.
- **Each narrowing is a token** above the results, Years, Person or Subject, which clears it; a type sets the document-type filter. While the panel is open, the count says what the search narrowed from, as the Mac's does.
- **A new search** keeps each section's sort and page size, the reader's preference, and drops its page, filter and staged rows, which described the last search's rows, as the Mac's panel does.
- **The subject's name** comes from the row that set it: the kit's subject vocabulary, which the Mac's token reads, is internal.

**Checked**

- **Through the API, beside the kit,** over the fixture index imported as an export (FRUSParityTests):
  - every section of four searches is the kit's breakdown cut by `FacetPaging`, with its bounds, counts and titles;
  - a sort, page size, page and filter of the browser app's choosing cut the rows as the kit cuts them, a page past the last clamped;
  - each row's narrowing makes the search `FacetNarrowing` makes, and that search counts the row's documents;
  - five staged selections of years and of volumes resolve as the kit resolves them, and the searches they give count the chosen rows.
- **On Linux, the facets read the immutable index the server opens:** `resultSetFacets` builds a temporary table, which the read-only open keeps in memory.
- **The label sort** (`localizedStandardCompare`) puts 20 sample labels, with accents, case, numbered volume ids and apostrophes, in the same order in `swift:6.4-noble` (locale `en_001`) as on the Mac (`en_US`), and the filter's accent-insensitive match agrees.
- **The synthetic export** now has its three documents' dates from their TEI, so the browser suite's facets have years: 1960 for frus1961-63v06's d1 and d2, 1894 for frus1894Nicaragua's d1.

**A review before the pull request opened.** Two reviewers, one for the server and one for the browser app and the records, each checked their own findings against the code. Nine held, and all were fixed:

- **Apply over rows counted before a new index** could widen the search: the kit drops a key its list does not hold, and a volume selection of nothing but such keys clears the filter. The server now refuses such a key as `SECTION_CHANGED` (409), and the browser app counts the section again and drops the choice.
- **The cache had no tests.** Its computation is now a closure, and four tests show it computing a section once, a concurrent ask waiting for the same computation, the least recently used going when it is full, and a failure not kept.
- **A test would have crashed** rather than failed with too few rows, and checked one of the coverage figures where it now checks them all.
- **"Narrowed from"** was said when the match had not shrunk, and while the narrowed search was still loading; it is now said only of a smaller match, as on the Mac. The panel's "Describing all N matches" waits for the new count too.
- **A failed Apply's message** stayed under the next search's rows, and an answer that came back after another search would have been applied to the old one. Both now belong to the search they were for.
- **Focus fell to the page** when Clear, Clear filter or a token removed itself. It goes to the section, the filter field and the search box.
- **Wording:** a hint of the web's own hid the Mac's tooltip on a narrowing row, and the toggle's tooltip now reads "Hide the result-set facets" while the panel is open, as the Mac's does.
- **The records** said a type narrowing makes a token, where it sets the Document type filter, and that a section is computed once, where the 16 most recent are kept.
- **The sort and page-size menus** snapped back while a page loaded, and closing the panel lost each section's choices, which the Mac's controller keeps. The menus follow the reader's choice, and the screen keeps the panel's state.

Refuted, among others: a year list's emptiness lost on the way to the URL; a field a narrowing sets that the URL drops; a section of another search standing in; collisions in the cache's keys; and the temporary table on the read-only index.

**Records**

- `PLAN.md` and its shared copy (rev 153): S11d's row, S11e's, and the S11 answers.
- `SPEC.md`: the Search section, the API table and the facets' departures from the draft.
- `INSTALL.md`: the facets. The README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through the Test step's own script: all 1,928 tests pass, up from 1,914, with the one named skip. FRUSParityTests runs 104, up from 100, and FRUSLightServerTests 87, up from 77; the other targets are unchanged.
- **The browser app:** typecheck and lint are clean, and 50 unit tests pass in 12 files, up from 40 in 11.
- **`scripts/compose-smoke --e2e`:** passes, with 11 browser tests on Chromium, up from 10. The facets test runs axe with a year staged, and with every section open over a narrowed match, and it finds nothing.

**Notes**

- **Check 12's facet time** (one section within 3 seconds) is not measured here: the fixture index is three volumes. The kit measured the slowest section, People, at about 0.8 seconds over a whole-corpus match on the owner's 316,839-document index (`ResultSetFacets.swift`), and notes that paging by query would pay that again for every page; the cache is why a page here does not.
- **A person's rollup is the served index's:** a new import can number the rollups afresh, so a saved address that narrows to a person may name another after one. The app's anchor, which survives a rebuild, has no field in the API yet.

**Next: S11e,** the rest of the search features over the API and in the browser app: the Query Inspector, with the term that matched nothing; the date order; and the timeline and concordance readings, each naming the set it counted. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11c, follow-up: a reader page opened at a note keeps focus on its controls

13 October 2026 · branch `claude/s11c-note-focus` · upstream `757c6d29`, unchanged

The owner merged #33 and asked for the follow-up S11c's review had offered, before S11d.

**What was wrong**

- A reader page opened at a note (`/doc/…?note=…`) lands on the note when its frame loads.
- Another text size or appearance loads the page again, in a new frame, and that frame's load landed on the note again: focus moved from the Text Size or Appearance control into the frame.
- A keyboard user who changed either control lost their place in it (WCAG 2.2, success criterion 3.2.2, On Input). The behaviour dated from S9b; S11c's wash made it easier to see.

**The fix**

- The reader lands on a note once for each arrival at it, by a link or by Back and Forward: it keeps the document and note it arrived at, and the next frame to load lands on that note once.
- A page loaded again for another text size or appearance leaves focus on the control that asked for it, and the frame's URL fragment keeps the note in view.
- `SPEC.md`'s reader rendering says so.

**The test**

- A new browser test follows d21's link to footnote 2 of d16, then changes Text Size and Appearance from the keyboard, and checks after each that the control keeps focus. Back and Forward then land on the note again.
- It counts the frame's load events at the document, which it sees before the frame's own handler runs in the same dispatch, so it checks focus only once that handler has run.
- Against `main`'s image, before the fix, it failed where it should: after the text size changed, the control was no longer focused.

**Results**

- **The browser app:** typecheck and lint are clean, and its 40 unit tests pass.
- **`scripts/compose-smoke --e2e`:** passes, and so do the browser suite's 10 tests on Chromium, up from 9: the new one, and the rest as before, the landings by a link and in place among them.
- **Linux:** the server's code is unchanged; CI's swift job runs its tests.

**Next: S11d,** the search features over the API and in the browser app: the facets with include, exclude and Apply; the Query Inspector; the date order; and the timeline and concordance readings. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11c: BibTeX and RIS in Cite, display titles, the footnote landing, and a sturdier skip check

13 October 2026 · branch `claude/s11c-cite-titles-footnotes` · upstream `757c6d29`, unchanged

The owner merged #31 and #32, and asked for the phase-1 features. They became two pull requests, as S8's and S9's did: this one brings the citations, titles and reader features of #1666 to the API and the browser app, and S11d brings the search features of #1664. On the owner's word it also changes CI's skip check, after the `ci` run on `main` for #31's merge failed with every test passing.

**CI's skip check**

- **What failed.** Run 38490727044, on `7258ee58`, failed in the swift job's Test step:
  - all 11 targets reported passing, with the counts of #31's green run on the same tree;
  - but the step counted the named Linux-only skip 0 times, because about 240 lines of the test output never reached `test.log`: 156 "started" lines, 71 "passed", the skip's own line and a few log lines, all in FTS5StoreTests and FRUSCoreKitTests;
  - 16 lines arrived as their ends only, such as `t" started.`;
  - the backup-exclusion test's skip is a compile-time `.enabled(if:)`, so it was skipped as always. The `image` workflow does not depend on `ci`, and published that commit.
- **The change.** The Test step passes `--xunit-output`, and counts Swift Testing's skips in the results file it writes, `test-results-swift-testing.xml`:
  - each skip is a `<skipped>` element under its test's suite and function, and the backup-exclusion test (`FTS5StoreTests.FTS5StoreTests`, `backupExclusion()`, a reason beginning "Linux: ") must be the only one;
  - the log is still read for what the file cannot show: XCTest's skips, for which no file is written here, and cancellations, which the file records as passing. A lost line can hide one of those, but never fails the job;
  - `COORDINATION.md`'s pin-move checklist says how the allow-list now works.
- **How it was checked:**
  - a probe package in `swift:6.4-noble` showed what the file records for each kind of skip: a trait's, a disabled suite's (once for each of its tests), one with no reason, one with a reason over two lines or with XML's special characters, a cancellation and XCTest's;
  - the step's own script, read from `ci.yml`, ran in the swift image under `bash -eo pipefail`, with `LANG` unset and set to `C.UTF-8`, against nine cases replayed by a stand-in `swift`: the expected skip passes, and so does the failed run's own log; two extra skips (one with a reason over two lines, one with none), the named test run, skipped for another reason or found twice, no results file, an XCTest skip and a cancellation each fail;
  - this branch's full Linux run, through the same script: its results file holds 1,914 tests, one of them skipped, the backup-exclusion test.

**Cite**

- **The year.** The citation now takes the year the volume's TEI header states, read by the kit's `TEIPublicationYear` as both of the app's hosts read it, when the TEI is mounted.
  - Without the TEI, it takes the manifest's, with the Mac's fallback for the records, which the kit leaves to each host: `CitationRoutes.manifestYear` mirrors `DocumentExportSupport.effectiveYear`.
  - `publicationYear` and `publicationYearSource` (`tei` or `manifest`) say which.
  - Over HistoryAtState/frus at `99d851c79` (9 October), 552 of the 553 published volumes' headers state the manifest's year. frus1969-76v32's gives its date only as 2010-11-05, which the scan does not read, and the manifest gives 2010.
- **The records.** `bibtex` and `ris` are the kit's `BibtexExporter` and `RISExporter`, as the Mac's Copy BibTeX and Copy RIS write them; `…/citation.bib` and `…/citation.ris` serve them as files, named as the Mac names its .bib file.
  - The citation and both records are made from one volume's metadata, as iOS's reader makes them, so the printer's name follows the year cited.
- **The browser app.** Cite adds Copy BibTeX, Copy RIS and Save as .bib, in the Mac popover's wording, the last without its ellipsis, since a browser saves at once.

**Display titles**

- **Search rows** are named as the Mac's search window names them: the header less a leaked source note (`DocumentHeaderDisplay.trimmedHeader`), with the document's label beside its volume (`CitableDocumentNumber.captionLabel`), withheld when the header already opens with its number (`headerRepeatsNumber`). A row with no header takes the name the app's lists give it, where the window would leave it blank.
- **Every other list** (a section's documents, a volume's reading order) and **the reader's heading** take the kit's `DocumentDisplayTitle`: an editorial note whose head says only "Editorial Note" is named by its number, and a document with no head by its id.
  - The app names documents by it in its Research, working-corpus and cluster lists and its reader's title. Its Browse rows print the stored head (`DocumentRowLabel`), which for 2,560 notes is only "Editorial Note".
  - Browse here takes the kit's rule instead, which #1666 moved for the web edition's lists, so a row reads as the heading of the reader it opens. SPEC says so.

**The reader**

- **The footnote landing** is the app's own script: `/reader/host.js` holds the kit's `FootnoteLanding.script(keyExpression:)` byte for byte, as the body of `landOnFootnote(key)`, and runs it whenever the browser app asks it to land on a note, in another document after its page loads, or in place. The entry scrolls into view and is washed for 2.4 seconds; then it takes focus, as before.
- **A whole volume outside the catalogue**, such as the microfiche supplement v06's preface names, now carries its page on history.state.gov (`FRUSCanonicalURL.volumeURL`, public since #1666), which the app opens, and the reader offers it.

**A review before the pull request opened.** Two reviewers, one for the server and CI and one for the browser app and the records, each checked their own findings against the code. Six held, and all were fixed:

- **Cite's status:** a second copy said "Copied" again, which a live region does not announce, so Copy RIS after Copy BibTeX was silent to a screen reader. The status now empties before each copy. The browser test now waits for each record on the clipboard, where it had passed on the first copy's status.
- **"As the app's lists do":** the records said every list in the app names documents by `DocumentDisplayTitle`; its Browse rows do not. The comments, SPEC and the README now say that Browse here departs from them, and why.
- **Untested titles:** no browser-app test could tell a `displayTitle` from a `header`, or see a label withheld. Route-level unit tests now render Search, a section, a volume's reading order and the reader with the server's answers stubbed. With any of the four screens put back to `header`, or the label's guard removed, a test fails.
- **Cite's two rows of buttons touched**, and now have the gap they have when they wrap.
- **CI's results file is read as text** (`grep -a`), as the log is: a NUL byte in a skip's reason would otherwise fail the job.
- **`classify(asEditorialNote:)`,** which renames a document with the index's effective classification, had no test that could fail. The API cannot show it, since both read the same column, so a direct test does.

Refuted, among others: a mismatch between the types and the server's JSON; a download link styled as a button; the 2.4-second wash racing the tests; the host script's JavaScript under the page's policy; and the CI step's exit codes under `-e` and `pipefail`. One finding predates this session, so it is offered as a follow-up: on a reader page opened at a note, changing Text Size or Appearance reloads the frame, and the reload's landing pulls focus into it.

**Records**

- `PLAN.md` and its shared copy (rev 148): S11c's row, S11d's new one, S11b's row with the reused export, and the S11 answers.
- `SPEC.md`: the reader's landing, the API's search rows, list titles, the link's `url`, and the citation's year, records and files.
- `INSTALL.md`: Search's document numbers, Cite's three controls, the note's landing, and a volume outside the catalogue.
- `COORDINATION.md`, the README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** through the Test step's own script: all 1,914 tests pass, up from 1,908, with the one named skip, which the new check allows. FRUSLightServerTests runs 77, up from 71; the other targets are unchanged.
- **The browser app:** typecheck and lint are clean, and 40 unit tests pass in 11 files, up from 34 in 9.
- **The Compose smoke test with `--e2e`:** passes, and so do the browser suite's 9 tests on Chromium, up from 7. Axe runs over a note just landed on, the notice for a volume outside the catalogue, and Cite after its records are copied and saved, and finds nothing.

**Notes**

- **The Mac's popover gives the records the manifest's printer**, computed from the manifest's year, while iOS and this server compute it from the year cited. They differ only for a volume whose header and manifest name years either side of 2014, and no published volume does, so nothing is filed upstream.
- **A document the index lacks** keeps the name its TEI gives it ("Document 3"), and its records take its id for a title, as the kit's exporters do for an empty header: the kit's header extraction, `IndexingPipeline.extractHeader`, is internal.
- **The synthetic export's rows carry no document numbers**, so the browser suite sees "Doc 1" beside "1. Telegram From…", as the Mac's window would for those rows. The server tests give the rows numbers to check that the label is withheld, and the unit tests stub the answers.
- **Scratch files** from the CI checks are in `.build/linux` (`ci-test-step.sh`, `guard-cases/`), which git ignores; the session left them, since its safety check would not remove them for it.

**Next: S11d,** the search features over the API and in the browser app: the facets with include, exclude and Apply; the Query Inspector; the date order; and the timeline and concordance readings. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11b: pin move past S11a's two upstream pull requests

13 October 2026 · branch `claude/s11b-pin-move` · upstream `757c6d29` (#1666's merge, after #1664's `9feff971`)

The owner merged both of S11a's pull requests, and this one moves the pin to the second's merge (rule 5). It is stacked on #31, S11a's records, so #31 merges first.

**What the move brought**

- **The app's own work since `c6f7b2cb`:** `0fe15702` and `13e093ba` change only `Planning/` and the marketing kit, so build 50 stands. Its index version (69) and FTS generation (4) are unchanged.
- **#1664 and #1666:** the kit's public search, citation, title and reader code, which S11c builds on. Nothing in the web edition's own code needed a change: the server and its tests built and passed at the new pin as they were, and no kit folder, Linux-only skip or export schema changed.

**The golden files**

- **The export,** on the owner's word: the 13 October three-volume export from build 50, which build 50's pin move used.
  - The new pin is still build 50, so the export's `app_build` is the pin's.
  - No file on the indexing path changed between `c6f7b2cb` and `757c6d29`: the TEI parser, `IndexingPipeline.swift` and its seams, FTS5Store, SourceNoteKit and the bundled resources. So a new export would have indexed the same rows.
  - COORDINATION's checklist now allows such a reuse, by the owner's choice.
- **Remade by `scripts/make-golden --export`:**
  - all 392 rows' HTML and the 482 queries' expressions changed only in provenance;
  - the results changed only in provenance: 482 queries, 43 refused and 12 with ties past the 50th, as before;
  - in the index summary, no digest or count moved, only the provenance and the timings it records as information;
  - `frus-parity check-golden` passes.

**Records**

- `PLAN.md` and its shared copy (rev 144): S11a's row, Mac check 6 done, the golden-file checkpoint, the risk rows' counts and the S11 answer on the export.
- `COORDINATION.md`: the pin, the move and when an export can be reused.
- `SPEC.md`: the pin's index version and table lines. The prep notes, the README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** from a clean build of this package's own targets: all 1,908 tests pass, up from 1,797, with the one named skip, which CI's skip check allows.
  - By target: FRUSCoreKitTests 1,061, SourceNoteKitTests 310, FTS5StoreTests 209, FRUSParityTests 100, FRUSLightServerTests 71, ManifestGeneratorTests 60, FRUSLightCoreTests 42, SemanticVectorsKitTests 35, CrossRefKitTests 10, GeneratorKitTests 7, FTS5CheckTests 3.
  - Against the remade golden files the run printed:
    - "check 2 passes: 36 digests and 7 checks are the Mac's";
    - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups", and the same through the API;
    - "check 4 through the page: 392 of 392 rows identical".
- **The web app and the Compose smoke test with `--e2e`:** run by CI's web and compose jobs, since this pull request changes neither the browser app nor the server's code.

**Notes**

- **The source digest moved** with #1664 and #1666, as it does at every pin move, and so did nothing else in the golden files.
- **Next pin move:** `COORDINATION.md` says when an export can be reused, and when the owner needs to make a new one.

**Next: S11c,** the phase-1 features over the API and in the browser app: the facets with include, exclude and Apply; the Query Inspector; the date order; the timeline and concordance readings; BibTeX and RIS in Cite; display titles in lists; and the footnote landing with the app's own script. Browse's own-text rows, the daily upstream watch and the speed of exact-word search remain before a release.

## Session 11a: the phase-1 features' two upstream pull requests

13 October 2026 · branch `claude/s11a-phase1-upstream` · upstream [joshbotts/FRUS-Explorer#1664](https://github.com/joshbotts/FRUS-Explorer/pull/1664) and [#1666](https://github.com/joshbotts/FRUS-Explorer/pull/1666)

The owner used the S10 site and asked for the phase-1 features, which signs phase 1 off on its exit. SPEC's phase 1 lists features that S10's checks did not need, and their shared code was internal to the kit or in app files. This session opened two pull requests on `FRUS-Explorer`, both `Mac`-labelled for the owner's check. The owner merged the first, #1664, the same day as `9feff971`, and the second is rebased on it. Each moves that code into FRUSCoreKit or makes it public, and the app calls the moved code too, so nothing is copied here. The pin stays at `c6f7b2cb` until both have merged.

**#1664: search, merged as `9feff971`**

- The concordance (`KWICLine`, `KWICSort`, `ConcordanceResult` and `SearchService.concordance(for:parameters:radius:)`) and the facets (`ResultSetFacets` and its section, sort, paging, bucket, bound and request types) are public.
- `SearchService.resultSetFacets(parameters:request:documentKeys:)` is the route the app's facet panel took, moved: the match and filters the search runs, or a meaning search's keys. The panel calls it now.
- The facet panel's narrowing and staged selection move into the kit:
  - `FacetNarrowing` reads the subject vocabulary from the host's `IndexingResources`;
  - `FacetSelection`, `FacetRowState` and `FacetSelectionApplier` move with `stagedSections`, which the panel's controller held.
- The Query Inspector's model, `QueryInspection.swift`, moves whole, with its three passes public.
- `SearchSortOrder` moves with `sorted(_:)`, the date order both view models kept a copy of, and gains `String` raw values for the API.
- Its tests: FRUSCoreKitTests goes from 950 tests in 126 suites to 1,022 in 132.

**#1666: citations, titles and the reader**

- `BibtexExporter`, `RISExporter` and `ZoteroJSONExporter` with its items move into the kit; the Zotero exporter's SwiftData lookup stays in the app.
- `TEIPublicationYear` is the header scan both apps kept a copy of, and both call it, each with its own fallback.
- `DocumentDisplayTitle` with `Facts`, which was `CrossReferenceStore.DocumentTitleFacts`, and `DocumentHeaderDisplay` move into the kit.
- `FootnoteLanding` is the app's footnote landing script, byte for byte. `script(keyExpression:)` lets the reader's host here run the same script for a key it has only when the script runs.
- `FRUSCanonicalURL.volumeURL(volumeId:)` is public, the page a reference to a volume outside the catalogue opens.
- Its tests: FRUSCoreKitTests goes from 950 tests in 126 suites to 989 in 133.

**How both were checked**

- **#1664,** at its head, whose tree `9feff971` is:
  - `FRUSExplorerMac`, clean and unsigned, built as `v2` at `13e093ba` did, with the same five warning lines. Its symbol diff, normalized, has 27 removed and 37 added names, each one the move accounts for.
  - The full iOS unit run on iOS 27.0: 7,147 tests in 844 suites, against `v2`'s 7,139 in 842. Both have the same 8 issues, the Keychain tests an unsigned build fails, and the same 17 tests and 2 suites skipped.
  - `swift test`: 38 runs and 2,852 tests, none failed or skipped.
- **#1666,** at its head on `9feff971`:
  - `FRUSExplorerMac`, clean and unsigned, beside `v2` at `9feff971`, with the same five warning lines. Its symbol diff, normalized, has 107 removed and 131 added names. Nearly all of that is the facts type's new mangled name, `DocumentDisplayTitle.Facts`; with that rename undone it is 5 and 29, each one the move accounts for.
  - The full iOS unit run: 7,158 tests in 847 suites, against `9feff971`'s 7,147 in 844. Both have the same 8 Keychain issues and the same skips.
  - `swift test`: 38 runs and 2,891 tests, none failed or skipped.
- **Linux,** in a scratch worktree of this repository's `main` with each branch copied over the submodule:
  - FRUSCoreKitTests pass with the one named skip: 1,022 for #1664, and 1,061 for #1666 on it;
  - every other target passes except FRUSParityTests, whose 13 issues are all golden-file staleness. The source digest covers the kit's folders, and S11b remakes the files;
  - remade at each branch with `tools/mac-golden`, the 392 rows' HTML and the 482 queries' expressions are byte-identical to the committed golden files; only the two provenance lines differ.

**Delivered here**

- `PLAN.md` and its shared copy (rev 136): the phase-1 sign-off, S11a–S11c and Mac check 6, the answers for S11, the risk row and the count of owner steps.
- `COORDINATION.md`: the two pull requests among the web-authored moves.
- The README and this log.

**Notes**

- **The editable-content docs pin strings to source lines.** Moving code shifted 60 of their ranges in #1664 and 6 in #1666. `EditableContentKeyTests` caught it in a first iOS run, and the ranges were re-pointed through a line diff of each file, each by the distance its own key moved.
- **A new kit suite must not reuse a name the app's test target declares.** The package builds the kit's suites alone, and Xcode compiles them into one module with the app's. A first `FRUSCanonicalURLTests` collided with the app's suite of that name and became `CanonicalVolumeURLTests`.
- **The two pull requests touch the same lines:** `CLAUDE.md`'s FRUSCoreKit entry, and the ends of `Planning/DEVELOPMENT-PLAN.md` and the amendment log. #1666 was not yet pushed when #1664 merged, so it was rebased on `9feff971`, the three conflicts were combined, and its checks ran again at that head.
- **Disk:** the Mac had 13–15 GB free throughout. The checks reused S6's derived-data folders and its scratch clone, and the worktrees for `v2` and #1666 share the clone's objects.

**Next: the owner's Mac check of [#1666](https://github.com/joshbotts/FRUS-Explorer/pull/1666), and its merge.**
- **Then S11b:** the pin move past both. It needs a new three-volume export from the merged build for the golden files.
- **Then S11c:** the features over the API and in the browser app.
- **Still before a release:** Browse's own-text rows, the daily upstream watch and the speed of exact-word search.

## Session 10: the owner's export in Compose, with checks 3–5 on it

13 October 2026 · branch `claude/s10-real-export`

S10 imported the owner's full export from build 50 into a Compose install and ran checks 3–5 on it. That is phase 1's exit, which waits on the owner's sign-off. On the owner's word, S10 ran on build 50, before the phase-1 features' upstream pull request.

**The install**

- A Compose project of its own, `frus-s10`, on port 8081, set up as `docs/INSTALL.md` says: `compose.yaml`, and a `.env` naming the port, the TEI folder and the image CI published for `main` at `3963520`, the merge of #29.
- The TEI folder is the owner's clone of HistoryAtState/frus, mounted read-only. It is at `99d851c79`, the corpus that build 50's bundle and the export hold.
- The owner's own install, from S7's trial, was left as it was. It is on port 8080, with an older image and the 3 October export at index version 65.

**Check 5: import acceptance**

- **The export made with the owner's writing** went into the drop zone first. Import mode refused it at `checking_writing`, 7 seconds after it arrived: "This export includes your notes, summaries and tags." A refused file stays in the drop zone, so its copy was removed. The install guide now says to remove such a copy, since it holds the writing.
- **The stripped export** installed. It was ready 38 seconds after the copy began, serving 318,151 documents from 553 volumes at index version 69.
- **`scripts/check-stripped-export`,** new, then searched the stripped file for the writing in the export made with it. It prints counts only, as the owner chose over one planted string:
  - 6,558 summaries, 8 notes and 21 tags gave 7,102 snippets from 6,580 values; 7 values were too short to search for;
  - the controls held: the snippets were found in the export with writing for all 6,580 values, and 189 of 189 snippets of the corpus's own headers in the stripped file;
  - the stripped file's tables hold no summary, note or tag, and its `user_content` index no term, where the export with writing's holds 11,037;
  - 1,622 snippets appear in its bytes, all of them in its corpus text too, since those summaries quote documents. None is in the owner's writing alone.

**Check 3: search**

- **The Mac's results:** `mac-golden results --any-volumes`, new, ran the app's SearchService over a copy of the export. 482 queries took 32 minutes 37 seconds: 43 were refused, and 12 have ties past the 50th.
- **The server's:** `frus-parity results --api`, new, read the same queries through the Compose install's API, from a Linux container.
- **The first run:** 472 records were identical, and 10 failed in the client. Exact-word searches (`=Soviet` and the like) took longer than URLSession's minute while the server served check 4 too.
- **Read again** with a 15-minute timeout, the 10 answered: 21 requests in 989 seconds, the slowest 66. Merged into the first run, `frus-parity compare-results` printed "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups". 349 queries have other score bits, which is information, as through the API on the fixtures.

**Check 4: the reader**

- **The sample:** in each volume, the middle row of its index that is not front matter. That is 553 documents, from frus1861 to frus1989-92v31.
- **The Mac's HTML:** `mac-golden render --tei --rows`, new, rendered them from the clone through the Mac reader's path, in 2 minutes 11 seconds. The reader applied the bundled broken-references index as the app applies it: the tool puts the index beside its binary, where `BrokenRefsIndexStore.shared` reads it, and checks that the reader finds it.
- **The server's:** `frus-parity render-api`, new, fetched each document's body from the server and compared the bytes: "check 4 through the API: 553 of 553 rows identical, 14 figure images in 2 rows named by the server".

**Delivered**

- **`tools/mac-golden`:** flags in its parser; `results --any-volumes`; and `render --tei --rows --out`, which refuses an `--out` inside `fixtures/golden`.
- **`frus-parity results --api` and `render-api`,** over `LiveAPI` in FRUSParity. Its loop is ParityFormat's `ResultsLoop`, as the tests' and the Mac's are. A request may take 15 minutes, and `results` prints its slowest requests.
- **Tests:** ServedAPIParityTests' checks 3 and 4 through the API also read through `LiveAPI`, and find the same records and bodies. So CI runs the code S10 ran.
- **`scripts/check-stripped-export`.**
- **Records:**
  - `INSTALL.md`: removing a refused copy that holds the owner's writing;
  - `SPEC.md`: how a release runs checks 3–5 against a real export;
  - `PLAN.md`: the answers for S10;
  - the README and this log.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,797 tests pass, with the one named skip.
- **On the owner's export:** checks 3, 4 and 5 pass, as above.

**Notes**

- **Exact-word searches are slow over the full corpus.** On the server, with nothing else running, the 10 queries' 21 requests took 989 seconds, about 47 each, the slowest 66. SPEC's check 12 targets 1.5 seconds for keyword search. The Mac app's own search took 11 minutes 22 seconds for the same 10 queries, its copy of the export included, and gave the same records: the time is the search's own, on both platforms. Check 12 is phase 5's, and this is its first measurement.
- **The server searched on one core.** It held one CPU at 100% throughout, at 218 to 270 MiB.
- **A request the client abandons runs on.** After the 10 timeouts the server went on computing those searches: a dropped connection does not stop the kit's search.
- **The Mac slept during the owner's pause,** and Docker's VM with it. The runs took nine hours of wall time, but about 45 minutes of the VM's.
- **The Mac's disk** had about 17 GB free. The tool's 2.9 GB copy of the export was removed when it finished.
- **The owner's own install** still serves the 3 October export at index version 65, from an image older than #29. Upgrading it means pulling the new image and importing an export from build 50.

**Next: the owner's sign-off of phase 1.** In PLAN's checkpoint, the owner uses the site and confirms checks 3–5; the S10 install at http://localhost:8081 serves the export. Then the phase-1 features' upstream pull request. Browse's rows for a section's own text, the daily upstream watch and the speed of exact-word search remain before a release.

## Pin move: build 50, at index version 69

13 October 2026 · branch `claude/frus-upstream-changes-bd0cb7` · upstream `c6f7b2cb` (tag `build-50`)

The session began by reading what had changed upstream since S9c's pin, in FRUS Explorer, frus-semantic-vectors and HistoryAtState/frus, to say whether the web edition should catch up before S10. It should: the owner's full exports for S10, made from build 50, are index version 69, and the server at `f384d2d5` served only 65. On the owner's word this pull request moves the pin (rule 5).

**What had changed upstream**

- **FRUS Explorer:** 41 commits on `v2`, from `f384d2d5` to `0fe15702`. Four index bumps merged on 11 October, 65 to 69 ([joshbotts/FRUS-Explorer#1638](https://github.com/joshbotts/FRUS-Explorer/pull/1638), [#1639](https://github.com/joshbotts/FRUS-Explorer/pull/1639), [#1640](https://github.com/joshbotts/FRUS-Explorer/pull/1640) and [#1645](https://github.com/joshbotts/FRUS-Explorer/pull/1645)), and ship together in build 50, which the owner tagged on 13 October at `c6f7b2cb`; `0fe15702` changes only `Planning/`. Upstream's brief for the bumps planned it so: "The web side moves its pin once, after the last." The FTS generation (4) and the exporter are unchanged.
- **HistoryAtState/frus:** from `8e5da08` (release 1.1.1) to `99d851c79` (1.1.3, 9 October). 26 volumes were corrected (HistoryAtState/frus#470), and 47 documents restored to frus1952-54v09p1 (HistoryAtState/frus#471). No volume was added or removed, and the three fixture volumes are byte-identical, so `fixtures/tei` stands. Build 50's bundle is at `99d851c79`.
- **frus-semantic-vectors:** the shards of frus1952-54v09p1 and frus1902app1 were re-packed in place for those corrections, and the README and manifest now describe 553 shards; the provenance digest is unchanged. The web edition reads shards only from phase 4. A pin before `f23092ec` bundles the older shard manifest, which refuses the two new shards; this one bundles the new.

**The owner's exports**, read only in SQLite's immutable mode:

- **The full corpus, from build 50:** one export without the owner's writing (2.86 GB), and one with it, for check 5, of which only the stamp and counts were read. Both are index version 69 and FTS generation 4, with 553 volumes and 318,151 documents, the 47 restored ones among them, and no sidecar file. Their library has a long history: its `person_mentions` lacks the UNIQUE constraint fresh libraries have had since June, with no duplicate row, and 162 revision rows at index version 62 name documents no longer indexed. Neither stops an import, since for a stamped export the server reads the stamp.
- **Three volumes, from build 50,** for the golden files: exported at 05:21:01Z after Erase Everything…, with no writing, exactly the three fixtures (139, 123 and 130 documents, every revision at 69), indexed in the order frus1894Nicaragua, frus1961-63v06, frus1969-76ve09p1.

**Delivered**

- **The pin, `c6f7b2cb`.** Every kit builds and passes on Linux, with no new skip and no upstream repair: FRUSCoreKitTests runs 950 tests in 126 suites, up from 894 in 119.
- **Index version 69.** `IndexCompatibility.supportedIndexVersion` follows the pin, so the server now refuses build 49's exports, naming both versions.
- **A reference to a whole volume.** The kit reads one as `CrossRefDestination.volume` since [joshbotts/FRUS-Explorer#1603](https://github.com/joshbotts/FRUS-Explorer/issues/1603), and the link route's switch over the kit's destinations had no case for it, the move's one break. The route now answers `volume`, with `volumeId` and what the server holds of the volume. The browser app opens a catalogue volume in Browse, as the app's `WholeVolumeLink` does. The app opens any other volume's page on history.state.gov, an address the kit keeps internal (`FRUSCanonicalURL.volumeURL`), so the reader says the volume isn't part of the collection. The server test that pinned the old reading, a document named `frus1961-63v05`, now pins the new, with Volume V, the volume itself and the microfiche supplement the preface names.
- **The schema fixture,** `export-v69-schema.sql`, from the three-volume export, in place of `export-v65-schema.sql`. It holds version 65's statements in their order, and one more: the partial index `idx_document_cache_user_tag_ids`, which [joshbotts/FRUS-Explorer#1614](https://github.com/joshbotts/FRUS-Explorer/pull/1614) added on 9 October with no index version. No table changed, so `IndexSchema.swift`'s list stands.
- **The golden files,** remade by `scripts/make-golden --export`:
  - all 392 rows' HTML and the expressions changed only in provenance, and the render manifest's description now names the reader serializer's third setting, `listsNamedReferences` (#1599), and the release build;
  - in the results, only q324 and q430's tie at the 50th place moved: S9c's export had swapped it, and this one, indexed in the recommended order, swaps it back;
  - the index summary's 7 checks are unchanged, and seven of its 36 gating digests moved. Six follow the bumps: `cross_references`, its rows and their order (66: a reference to a footnote is an edge to its document, and one to a whole volume a row between volumes), `terms` (66: line breaks folded), `document_sources` and `volume_sources` (69: the class key) and `document_revisions` (every row at 69). The seventh, `schema`, is #1614's partial index.
- **`scripts/make-golden` builds `tools/mac-golden` in release.**
  - At build 50 the tool's debug build failed under Xcode 27.0, though Xcode builds the app. In one of the compiler's batches, `ForEach(cols)` in `ResearchRailView.swift` found the `@Model` class `Collection` not Identifiable.
  - A bisect put it at `845d57ea` (#1645), which edits neither file. A probe naming the conformance in `ResearchRailView.swift` made the module build, and a whole-module compile type-checks it clean, so the fault is the debug build's and not the app's.
  - Release compiles the module whole, and `-enable-testing` keeps the tool's `@testable import`. At `f384d2d5` the release-built tool wrote render, expressions and results byte for byte as the committed golden files. The tool's header and its render description say how it is built.
- **Tests that named 65 as the pin's version** now read `IndexCompatibility`, and the parity tests' synthetic export stamps the submodule's build. The summary's own test still names the build, now 50, so a build bump shows there. Literals that stand for another version, or for test data, stay.
- **Records:**
  - `COORDINATION.md`: the pin, the counts, the contract and this move;
  - `PLAN.md` and its shared copy (rev 126): the move, the golden-file and Mac-export checkpoints, and two risk rows;
  - `SPEC.md`: the table definitions' lines, the compatibility contract and the link route;
  - `INSTALL.md`: the version, whole-volume links and the first version change on upgrade;
  - the prep note and the README.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** from a clean build of this package's own targets: all 1,797 tests pass, up from 1,723, with the one named skip, which CI's skip check allows.
  - By target: FRUSCoreKitTests 950, SourceNoteKitTests 310, FTS5StoreTests 209, FRUSParityTests 100, FRUSLightServerTests 71, ManifestGeneratorTests 60, FRUSLightCoreTests 42, SemanticVectorsKitTests 35, CrossRefKitTests 10, GeneratorKitTests 7, FTS5CheckTests 3.
  - Against the new golden files the run printed:
    - "check 2 passes: 36 digests and 7 checks are the Mac's";
    - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups", and the same through the API;
    - "check 4 through the page: 392 of 392 rows identical".
- **The web app:** typecheck, lint and 34 unit tests.
- **The Compose smoke test with `--e2e`** passes on the local arm64 image, whose client stage builds the web app. The suite runs seven tests on Chromium, one of them new: "volume V" in d7 opens Volume V in Browse, and the microfiche supplement the preface names says it isn't part of the collection. The axe test still allows nothing.

**Notes**

- **No watch caught the bumps.** COORDINATION's daily job, which would build `v2`'s head on Linux and compare its index version with the pin's, was never added, so four index bumps and a build went unseen here until this session looked.
- **Browse lists no section's own text yet** ([joshbotts/FRUS-Explorer#1536](https://github.com/joshbotts/FRUS-Explorer/issues/1536), index version 68). The app's Browse lists it first in its section; the server's section page lists the section's documents alone. No fixture section has such a row. The corpus has them for 1,337 sections that hold documents and 33 that hold only sections. The reader's order holds them already, through the kit.
- **A volume outside the catalogue** gets history.state.gov's page once the kit makes `FRUSCanonicalURL.volumeURL` public: a line for the next upstream pull request.
- **Rule 4 glue:** the choice between a person's two counts, the `fnote-` prefix, and now the whole-volume choice, in the browser app.
- **The person rollup can depend on indexing order** ([joshbotts/FRUS-Explorer#1658](https://github.com/joshbotts/FRUS-Explorer/issues/1658)). A fix would move `currentPersonRollupVersion`, not the index version, and every fixture person's rollup has one member, so check 2 cannot show it.

**Next: S10, when the owner says.** Its input is the owner's build-50 export. The plan timed the phase-1 features' upstream pull request so its pin move came just before S10's export; the export now exists, so the owner decides between S10 on build 50, with the features after, and the features first, with another pin move and new exports if the index version moves. Browse's own-text rows and the daily watch are each a small pull request before S10.

## Session 9c: pin move to the AA reader and the kit's link parse, with page links and mention counts

7 October 2026 · branch `claude/s9c-pin-move` · upstream [joshbotts/FRUS-Explorer#1578](https://github.com/joshbotts/FRUS-Explorer/pull/1578) (merged as `4fc04a60`) and [#1579](https://github.com/joshbotts/FRUS-Explorer/pull/1579) (merged as `f384d2d5`)

S9b's two upstream pull requests merged on `v2` after the owner's Mac check. #1579 needed a merge of `v2` first, made in S9b's clone: both pull requests had added a session entry at the end of `Planning/DEVELOPMENT-PLAN.md`. The merge kept both, and its head was checked again:
- the Mac build;
- the full iOS unit run: 6,516 tests, failing only the 8 Keychain tests an unsigned build fails, with the same 17 tests and 2 suites skipped as on `v2`;
- `swift test` from an empty build folder: 38 runs, 2,557 tests;
- FRUSCoreKitTests on Linux: 894.

This pull request moves the pin to `f384d2d5` (rule 5) and remakes the golden files from the owner's new export. It also brings what S9b deferred until then:
- the kit's link parse in place of the server's mirror of the app's;
- page links, through `PageRangeStore`;
- the person card's count, through `PersonMentionStore`;
- no axe allowance.

The index version (65), the FTS generation (4) and the app's build (49) are unchanged, so the image, `compose.yaml` and the export contract are too.

**How the session got there**

- **A map first.** Two readers mapped:
  - what the move makes stale in the records, the build and the golden files;
  - the kit's two stores, the Mac's use of each, and fixture data to test them.

  `Package.swift` needed no change: the folder the kit's tests compile picks up #1579's new suite. Two of their findings shaped the tests:
  - **No fixture document has a page link within its own volume;** such links are only in the tables of contents and indexes, which the reader cannot open. So the parity test writes its own page links, every arabic page of each volume, in the serializer's form.
  - **The synthetic export had the person and page tables but no rows.**
- **A review before the pull request opened.** Four reviewers each had a skeptic check their findings. Four findings held, and all were fixed:
  - **The count's number:** the card wrote it ungrouped ("4512"), but the app's localized string groups it ("4,512"). With the full corpus, counts in the thousands will appear.
  - **A test gap:** no test sent a page link that names another indexed volume, so a lookup in the wrong volume would have passed. The parity test now sends Nicaragua's pages 9 and 15 from frus1961-63v06, whose own pages 9 and 15 hold other documents.
  - **Two records:**
    - SPEC had stopped naming the app code the server copies, the choice between a person's two counts;
    - one of PLAN's S9 answers lacked its "Done in S9c".

  The server's reviewer found nothing. The two refuted points: the person test's slack of four, since all 121 persons are counted; and a missing test that the stores open immutably, which the code shows and #1579's own tests prove.

**The owner's export**

Made on 7 October from a build of `f384d2d5` after Erase Everything…, and read here only through SQLite's immutable mode:
- exported at 10:28:02 UTC, after #1579 merged at 10:15:33 UTC;
- build 49, index version 65, FTS generation 4, with none of the owner's writing;
- exactly the three fixtures, 139, 123 and 130 documents, every revision at index version 65;
- 1,130 page ranges and 1,018 person mentions;
- no log or journal beside it.

`make-golden` copied it to a temporary folder and worked on the copy alone.

**Delivered**

- **The pin, `f384d2d5`.** FRUSCoreKitTests runs 894 tests in 119 suites on Linux, up from 884 in 118.
- **The golden files,** remade by `scripts/make-golden --export`:
  - all 392 rows' HTML, the expressions and the index summary's 36 gating digests and 7 checks are as before. #1578 changed the page's head, which the golden bodies leave out;
  - only provenance and information fields changed. These include the export's stamp, its size, its AUTOINCREMENT counters, which grew by exactly one indexing, and `volumeOrder`;
  - this export indexed frus1969-76ve09p1 before frus1961-63v06. So in q324 and q430, both "see", the 50th result and its exactly tied successor changed places. Check 3 passes that as a reorder within a Mac tie group, and now reports 480 identical and 2 reordered.
- **The link route** reads each link with `FRUSURLScheme.readerLink(from:)`. The server's mirror of the app's parse, and its tests, are gone; #1579's tests cover the parse upstream.
- **The served stack** opens `PageRangeStore(readingDatabaseAt:)` and `PersonMentionStore(readingDatabaseAt:)` beside the search stack, inside the same check that the path still names the served file.
- **Page links:** a page link lands on the document the index's page ranges place on its page. Of several documents there, it takes the one its footnote names, as the app opens it. With no index, or for a volume or page the index lacks, the reader says why.
- **The person card:** for a person in the volume's list, it shows "In Indexed Documents" and "Mentioned in N indexed documents", or "Not found in indexed documents", in the app's words. The count is the person's rollup across the corpus, else their documents in the volume, as `DocumentViewModel.loadPersonMentionCount` decides. That choice is app code, so it is recorded glue. Find all mentions is left out, as iOS leaves it out where Search cannot open: it needs a person filter in Search.
- **The synthetic export,** in both generators, holds the page ranges and person rows a real export holds for its documents. Khrushchev has a rollup and Kennedy does not, so the two counts take different branches.
- **The axe check** allows nothing: the kit's page meets WCAG 2.2 AA since #1578. The known list and the two checks that it was still needed are gone.
- **Records:**
  - `COORDINATION.md`: the pin, both merges, what the move did, and how download order affects exact ties;
  - `PLAN.md` and its shared copy (rev 118): the S9c row, Mac check 5, the golden-files and risk rows, and the S9 answers marked done;
  - `SPEC.md`: Reader rendering step 4, the link route and the compatibility contract;
  - `INSTALL.md`: page links and the card's count;
  - the prep note and the README.

**Results**

- **Linux, `swift:6.4-noble`, arm64,** from a clean build of this package's own targets: all 1,723 tests pass, up from 1,711, with the one named skip, which CI's skip check allows.
  - FRUSCoreKitTests: 894 in 119 suites.
  - FRUSParityTests: 100, up from 98. Its new suite prints "page links through the API: 897 links, 885 placed on a document, every one as the app's store places it" and "person counts through the API: 121 of 121 persons in the reader's lists, each as the app counts them".
  - FRUSLightServerTests: 71. The parse's suite is gone, and a test of the counts and of pages before an import is new.
  - Against the new golden files the run printed:
    - "check 2 passes: 36 digests and 7 checks are the Mac's";
    - "check 3's results pass: 482 queries, 480 identical and 2 reordered only within Mac tie groups", and the same through the API;
    - "check 4 through the page: 392 of 392 rows identical".
- **The web app:**
  - typecheck, lint, and 34 unit tests, the card's count among them;
  - the build.
- **The Compose smoke test with `--e2e`** passes on the local arm64 image. The suite runs six tests on Chromium:
  - the done-when walk, whose Khrushchev card now shows "Mentioned in 2 indexed documents";
  - a page link from d1's frame to page 2, which lands on d2, and "vol. XIV, p. 387" in d21, which says the volume is not indexed;
  - the footnote landing and the volume off the server;
  - axe, with nothing allowed anywhere: the reader's frame, light and dark, passes;
  - S9a's two tests.

**Notes**

- **The fixtures cannot show which count branch ran:** every fixture person's rollup has one member, so the rollup's count equals the volume's. The server test sets the synthetic rollup's count apart to show that the rollup wins.
- **The tools still cannot tell exports of `101e17d7` and `f384d2d5` apart.** Only `exported_at` and the procedure distinguish them.
- **Download order** decides how exact ties at the 50th place fall in the golden results. Adding the volumes in the order frus1894Nicaragua, frus1961-63v06, frus1969-76ve09p1 keeps check 3's report steady across exports.
- **Rule 4 glue left:** the choice between a person's two counts, and the `fnote-` prefix the kit's serializer gives a note's entry.

**Next: S10.** The owner's real export imported into Compose, with the TEI folder mounted read-only; checks 3–5 pass on the real export, which is phase 1's exit. The phase-1 features' upstream pull request (the reader's scripts, facets, the inspector, date order, display titles, BibTeX and RIS) is timed so its pin move comes just before S10's export.

## Session 9b: Browse, the reader's links and cards, by keyboard and checked by axe

7 October 2026 · branch `claude/s9b-browse-links` · upstream [joshbotts/FRUS-Explorer#1578](https://github.com/joshbotts/FRUS-Explorer/pull/1578) and [#1579](https://github.com/joshbotts/FRUS-Explorer/pull/1579), open

S9's second pull request completes the phase-1 SPA. It adds Browse, the reader's links and their cards, a keyboard path through all of it, and an axe check in the browser suite. The pin stays at `101e17d7`. The session opened two upstream pull requests, which the owner checks on the Mac and merges; nothing here depends on them.

**The owner's decisions, 6 October** (PLAN, "Answered on 6 October, for S9")

- **Axe and the kit's palette:** the app's own markup may have no violations. Inside the reader's frame only the kit's known `color-contrast` and `link-in-text-block` are allowed, until the upstream palette pull request lands; a ratchet then fails the check.
- **Links:** resolved on the server by kit code, after a parse of the link that mirrors the app's dispatcher, with an upstream pull request to move the parse into the kit.
- **Page links and mention counts:** deferred until the kit's two index stores open immutably, in the same upstream pull request.
- **Browse:** the kit's alone. The app's arrangements, front-matter split and document counts wait for an upstream move.

**How the session got there**

- **A map first.** Five readers mapped:
  - the Mac's link handling and cards;
  - the Mac's Browse;
  - the server's pieces and the draft API;
  - axe and the keyboard path;
  - the fixtures.

  They found the four decisions above, and the facts the session built on:
  - every link decision is public kit API, and only the parse of the URL is app code;
  - the kit's light palette fails AA in the frame: person links 3.67:1, cross-references and footnote markers 4.02:1, datelines 3.98:1;
  - no fixture volume has a broken reference;
  - v06's d2 names d1 in a footnote, and d1's heading names Khrushchev.

  The server tests built from these predictions passed on their first run, the persons' and terms' strings included.
- **The browser suite caught two of the session's own mistakes:**
  - the shell moved focus to the heading on a page load too, so Skip to content was no longer the first Tab stop;
  - the narrow sheet's `inert` covered the reader's heading, so axe found no `<h1>`.

  Both are fixed.
- **A stale object in the incremental build.** The full Swift run crashed in FRUSParityTests while copying a `Volume` to encode it. The bad address was the ASCII of "https:/". The test file's object was from S9a: Swift 6.4's cross-module incremental build had recompiled none of the target's files after `Volume` gained stored properties. Rebuilding this package's own targets clean fixed it, and every test passed.
  - CI restores its build from an earlier run, so its swift job now deletes `.build/linux/out/Intermediates.noindex/FRUSLight.build` after the restore. That folder holds only this package's own targets; the dependencies stay cached.
  - `CLAUDE.md`'s building notes say the same for sessions.
- **A review before the pull request opened.** Five reviewers each had a skeptic check their findings. 17 of 28 held, and all were fixed:
  - **The frame's history.** Changing the frame's address added entries to the history inside it. After following a link to a page the browser had cached, Back moved the frame to the previous document while the heading and the Cite rail stayed on the current one, so Copy Citation would have cited the wrong document. Each page now loads in a new frame, and a note in the same document is revealed by the host script without navigating. The suite now checks Back's text and that a second Back leaves the reader.
  - **A long link:** an `href` of tens of kilobytes could keep a CPU busy for minutes in the kit's footnote pattern. Links over 2,048 bytes are refused before any parse.
  - **Hidden failures:** Browse's routes took TEI that would not parse for a volume without contents, and an index that could not be read for one that holds nothing. Both now report their problem.
  - **Names:** a document the index lacks was named by its raw id when it had no number ("intro1"). A prose section is now named by its title, as the kit's reading order names it.
  - **Focus:**
    - a new screen's heading took focus while it still held an id, so a screen reader announced "comp1". The heading now takes focus once it has its title, seeded from what Browse has already read;
    - a note landed on was out of reach of the keyboard. The note now takes focus;
    - a window narrowing below 900 px with the rail open dropped focus to nowhere. Focus now goes to the sheet;
    - a page loaded with Cite open put focus on Cite. Cite now takes focus only when the reader opens it.
  - **State:**
    - a card left open came back, unasked, after Back and Forward. A card or notice now clears with the document;
    - the catalogue's filter could drift from the URL after the header's Browse link or Back. It now follows the URL when anything else changes it.
  - **Presentation:**
    - document lists numbered rows whose headers already carry their numbers;
    - badges ran into the text before them for screen readers and braille.
  - **Tests:**
    - nothing showed the index's structure winning over the TEI's. The parity test now checks `structureSource` and the section ids against the index's;
    - the skip link was never activated in the suite;
    - the ratchet checked only `color-contrast`, and now checks both known ids;
    - the axe test's title claimed more than it covered. It now also covers Browse and a card in dark mode.

  The eleven refuted points include:
  - the nil-volume fallback and the in-place rule, which follow from the kit's own `CrossRefDestination`;
  - a full parse behind the volume page, which `readable` needs;
  - the note pattern's narrowness, which no footnote id in the corpus exceeds;
  - the count's live region, which speaks only when the count changes.

**The upstream pull requests**

Each was built in its own clone at a real path, reviewed by a skeptic, and fixed before it opened. Their descriptions hold the Mac check's commands and results.

- **[#1578](https://github.com/joshbotts/FRUS-Explorer/pull/1578): the reader's page meets WCAG 2.2 AA contrast and marks its links by more than colour.** Branch `claude/reader-aa-palette`, two commits.
  - Light accent `rgb(0,102,204)`, light and dark person names `rgb(0,121,107)` and `rgb(0,179,161)`, light secondary 60% black, and dark accent `rgb(64,156,255)`. Every text colour is at 4.5:1 or more on the page and on the editorial tint.
  - Person and cross-reference links have a quiet underline.
  - `ReaderPageTests`:
    - re-takes the eight head pins. Each head grew by exactly 519 bytes, and with the old values put back they hash to #1575's pins;
    - adds the WCAG arithmetic, a check of every text colour in both palettes, and the underline.
  - At its head:
    - `swift test`: 2,550 tests, all passed;
    - FRUSCoreKitTests: 887 on macOS and on Linux;
    - the Mac build, with the usual 5 warning lines;
    - the full iOS unit run, 6,508 tests, failing only the 8 Keychain tests of an unsigned build, plus a timing flake that `v2` shows too.
  - The owner's items are the colour choice and whether underlines belong on paper; the Mac's File ▸ Print draws the reader's page.
- **[#1579](https://github.com/joshbotts/FRUS-Explorer/pull/1579): the kit reads the reader's links, and the page-range and person stores open immutable.** Branch `claude/reader-link-parse-immutable-stores`, five commits, each of which passes the unit target on its own.
  - `FRUSURLScheme.readerLink(from:)` and `ReaderLink` are the app's dispatcher's parse, moved verbatim, and `dispatch(url:)` now switches on it.
  - `PageRangeStore(readingDatabaseAt:)` and `PersonMentionStore(readingDatabaseAt:)` open `FTS5Store.immutableURI(for:)`.
  - At its head:
    - FRUSCoreKitTests: 891 on macOS and on Linux;
    - `swift test`: 2,554 tests;
    - the full iOS unit run: 6,513 tests, failing only the 8 Keychain tests;
    - the symbol diff: 10 removed and 51 added, each named.
  - It reads a `person` or `gloss` link with no path as the empty ref, as the app always has. The server's parse here now does the same.

When both merge, a pin move:
- switches the server to `readerLink(from:)`;
- opens the two stores immutably for page links and mention counts;
- empties the axe list and its two checks.

**Delivered**

- **The reader's links:** `GET /api/v1/volumes/{v}/documents/{d}/link?href=` (`ReaderLinks.swift`).
  - `ReaderLinkParse` mirrors `FRUSURLSchemeHandler.dispatch(url:)`. A path's parts are decoded twice, a broken reference's target once, and a link's own volume is passed to `FRUSURLScheme.resolveCrossRefTarget`, as the app does.
  - A person or term comes from the reader's lookups, the parse the reader renders with. A broken reference comes from `BrokenRefsIndex.degradableInfo`.
  - A cross-reference gives its destination; a footnote also gives the note's entry id, `fnote-` and `FRUSRenderNode.footnoteDOMKey`. It says `inPlace` for a note of the same document, and what the server holds of the destination's volume, with its history.state.gov URL.
  - A page reference names its page and volume, and stops there.
  - An `href` over 2,048 bytes is refused before it is parsed.
- **Browse on the server:**
  - `/volumes/{v}` gives `structure`: the index's cached structure, else the kit's parse of the mounted TEI, with `structureSource`. Each section has the kit's flags, its document count and how many the index holds, and `readable` (the reader's parse makes it a document).
  - `/volumes/{v}/sections/{s}` lists a section's documents. A document the index lacks is named by `CitableDocumentNumber.rowLabel` ("Document 3"), and a prose section by its title.
  - TEI that will not parse is `TEI_UNREADABLE` on these routes, unless the index gives the structure.
  - `/volumes/{v}/documents/{d}` answers from the TEI for a document the index lacks, or before an import, and each neighbour says whether the reader can open it.
- **The host script:**
  - remembers the link it posted, and refocuses it when the parent asks;
  - scrolls to a note and gives it focus when the parent asks;
  - ignores a middle click on a reader link, which the sandbox would refuse as a popup;
  - lets Space activate an unresolved reference, which the kit marks as a button.
- **Browse in the SPA:**
  - `/` opens `/browse`, and the header gains Browse.
  - The catalogue's filter, subseries and indexed-only choices live in the URL, replaced as they change.
  - The volume page shows the publication, the editors, the coverage ("2 of 120 documents indexed on this server") and the section tree. Its fallback for a volume with no structure is the index's reading order.
  - The section page shows a breadcrumb, its subsections and its documents, with the badges Editorial Note and Not indexed on this server.
- **The reader's links in the SPA:**
  - a cross-reference goes forward, and Back returns;
  - each page loads in a new frame, so the frame adds no history of its own;
  - a note in another document lands through the frame's URL fragment, and one in the same document is revealed by the host script. Either way the note takes focus;
  - a volume not on the server gets a notice with its history.state.gov link;
  - external links appear in a notice with a real link, and page and unresolved references with a sentence;
  - a person, a term or an unresolved reference opens a modal `<dialog>` card with the Mac's titles, sentences and Done. Closing it returns focus to the link in the frame. The not-found cards keep the Mac's titles, with the web's own sentence;
  - Previous and Next replace the history entry, as the app's `DocumentJump` does, and hide a neighbour the reader cannot open.
- **Keyboard and WCAG fixes:**
  - each screen names the tab, and a new screen's heading takes focus once it has its title;
  - a card or notice clears when the document changes, by any route;
  - a search keeps its box's focus; the box is no longer remounted;
  - Escape closes the Cite rail, and below 900 px the toolbar and frame are inert while the sheet is open;
  - the toolbar is a labelled group, not an ARIA toolbar without roving focus;
  - the arrows on Previous and Next are hidden from screen readers;
  - controls have a 3:1 edge (WCAG 1.4.11), and badges carry a comma for screen readers.
- **The browser suite** (`@axe-core/playwright` 4.13.0, exact, with axe-core 4.13.0):
  - `web/e2e/fixtures.ts` fails any test on a console error;
  - `axe.ts` holds the check and the kit's known list;
  - `keyboard.ts` tabs to a target in the app or the frame;
  - `browse-link-card.spec.ts` runs the done-when walk, a footnote landing and a missing volume, and axe over every screen in both appearances and beside the narrow sheet.
- **Docs:**
  - `INSTALL.md`: what phase 1 offers, and step 6, which adds Browse, links and the API's new routes;
  - `SPEC.md`: Reader rendering step 4, the API table, four departures, and Browse's routes;
  - `PLAN.md` and its shared copy (rev 108): the owner's S9 answers, with the upstream pull requests;
  - `COORDINATION.md`: the two upstream pull requests.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,711 tests pass, up from 1,701, with the one named skip, which CI's skip check allows.
  - FRUSLightServerTests runs 71, up from 61: the link route for every kind of link, every link on five fixture pages, a broken reference from a decoded index, the refusals, the structure from the TEI, a section's documents, a document the index lacks, and TEI that will not parse.
  - FRUSParityTests' browse check now also requires the index's structure, by its section ids. The run printed check 3 and check 4 through the API as before, and "browse through the API: 3 volumes of 553 indexed, 139 of 140, 123 of 128, 130 of 134 entries in reading order held by the index".
- **The web app:**
  - typecheck, lint, and 33 unit tests in 9 files;
  - the build: `index.html` 0.5 KB, CSS 5.8 KB, and one script of 364 KB, 115 KB compressed.
- **The Compose smoke test with `--e2e`** passes on the local arm64 image, still 400 MB. The suite runs five tests on Chromium:
  - **the done-when walk, by keyboard alone:**
    - Skip to content first, and Enter on it leaves `main` focused;
    - the catalogue narrowed to one volume, then its page, focused at its heading ("2 of 120 documents indexed on this server");
    - its compilation, then d2;
    - Enter on "Document 1" in the frame goes forward to d1, focused at its heading;
    - Enter on "Khrushchev" opens the card "Khrushchev, Nikita S.", "Chairman of the Council of Ministers of the Soviet Union", focused at its title;
    - Escape returns focus to the link in the frame;
    - Back returns to d2 with d2's text, and a second Back leaves the reader;
    - axe at the catalogue, the volume, the section, the reader and the card: none of the app's own markup fails, and in the light reader the frame fails `color-contrast` alone;
  - a note in another document lands in view and takes focus, and a document in a volume not on the server gives its history.state.gov link;
  - axe over Search, the reader with Cite, the narrow sheet (whose text is inert, and Escape returns focus to the toggle), a card, and, in dark, the reader (whose frame fails `link-in-text-block` alone) and Browse's three screens;
  - S9a's two tests.

  That is S9b's done-when, read as the owner decided: no axe violations in the app's markup, and only the kit's known two in its frame, until #1578 lands.

**Notes**

- **The frame's known failures, as axe reports them:**
  - `color-contrast` alone in the light reader (frus1961-63v06 d2);
  - `link-in-text-block` alone in the dark reader (d1), where the links pass 4.5:1 but differ from the text around them by colour alone.

  The suite asserts each, so each id on the known list is shown to be needed, and a pin move that fixes one fails its check. The map had predicted `link-in-text-block` in light too, for a cross-reference among footnote text. axe does not count a link that is nearly all of its list item as a link in a block of text.
- **Rule 4 glue, recorded:**
  - `ReaderLinkParse`, about 20 lines, until the kit's `readerLink(from:)`;
  - the `fnote-` prefix the kit's serializer writes, joined to the kit's own `footnoteDOMKey`.
- **No fixture has a broken reference.** The server test decodes a one-record `BrokenRefsIndex`, renders d2's link as broken, and resolves it. The card's text has unit tests.
- **A target that names a whole volume** (`frus1961-63v05`) resolves, as the kit does, to a document of that name in the current volume, and the reader then says it has no such document. The links pull request files a `.volume` case.
- **`href="#"`:** a person or term with no ref is still a Tab stop that scrolls the frame to its top, as in the app, until the kit writes a span for it.
- **Parse cost:** the volume page and a document the index lacks parse the volume's TEI, about half a second for the largest, shared with the reader's cache of four volumes.

**Next: S10.** The owner's real export imported into Compose, with the TEI folder mounted read-only; checks 3–5 pass on the real export, which is phase 1's exit. Before it: the owner's Mac check of the two upstream pull requests, then a pin move that empties the axe list and brings page links and mention counts. The phase-1 features' upstream pull request is timed so its pin move comes just before S10's export.

## Session 9a: the browser app's foundation, and a citation copied in Chromium

6 October 2026 · branch `claude/s9-web-client`

S9 became two pull requests at the start, by the owner's choice: S9a meets S9's done-when first, and S9b completes the phase-1 SPA. The owner also chose three things before any code:
- npm through a Docker wrapper, `scripts/npm`, as Swift goes through `scripts/swift`;
- the publication year from the manifest now, rather than waiting for the app's TEI rule upstream;
- the citation endpoint in the kit and the server only, with no upstream pull request.

The pin stays at `101e17d7`, and nothing upstream changed.

**How the session got there**

- **A map first.** The map read the kit's citation API at the pin (`CitationStyle`, `makeFormatter`, `FRUSDocumentMetadata(citing:printedNumber:)`, `FRUSVolumeMetadata(entry)`, `CitationPlainText`, `CitableDocumentNumber`, `FRUSCanonicalURL`) and Hummingbird 2.27's middleware.
  - Router middleware applies only to routes added after it, and the not-found responder runs all of it.
  - `FileMiddleware` serves files only where a route has answered 404, and has no fallback for an SPA's client routes.
  - `ContentSecurityMiddleware` adds a second policy header, which would have doubled the reader page's.
  - The manifest's publication year equals the year the app reads from the TEI header for all 553 published volumes, so the manifest's year changes no citation.
- **A review before the pull request opened.** Five reviewers each had a skeptic check their findings. 26 of 32 findings held, about 20 once duplicates are merged, and all were fixed:
  - **HEAD /readyz answered 200 with the app's page** before any import. The router made no HEAD responder for its GET routes, so a HEAD fell through to the app's fallback. Every GET route now answers HEAD itself. The fallback's own HEAD had sent a length of 0; it now sends GET's headers.
  - **The router lays a route's checked search over the raw one,** so a field the check dropped kept the URL's string. A URL with `limit=20` paged to `offset=020`, then `2020`, and `offset=-5` or an empty date reached the server. The check now returns every field.
  - **Focus:**
    - focus did not reach a new screen's heading, because the shell moved it before the screen rendered; it now waits for the router's `onRendered`;
    - changing the citation style or the page unmounted the control that had focus. The previous citation (for the same document only) and the previous page of results now stay while the next loads, and Copy Citation waits for its own style.
  - **The reader and Cite:**
    - the page check refetched when the tab regained focus, and a failure then replaced an open document with an error;
    - the Cite toggle was a link, announced as the current page. It is now a button with `aria-expanded` that toggles in place, without a history entry;
    - below 900 px the rail sat below the frame, off screen. It is now a sheet over the text, with Close, and takes focus.
  - **Search:**
    - the same search could not be asked again after a refusal, and nothing was asked again once an index became ready;
    - a page past the end said both "2 documents match" and "No documents match.", with "Page 61 of 1".
  - **Preferences:** with storage blocked, a choice was lost on the next remount. Every reader now shares this page's choices.
  - **Strings:** `copy.ts` claimed the Mac's wording where it had a string, but differed. It now uses Copy URL, Document type with All, and Text Size, and claims no more than that.
  - **The citation endpoint:**
    - `numberSource` said `index` for a number the id spelled. It now says `documentId`, and is absent when there is no number;
    - the docs had described only `_…_`, but Chicago and Turabian write `*…*` around the whole title.
  - **Tests:**
    - the fallback test's reader path had an extension, so it never tested the `/reader/` exclusion;
    - the precedence test could not tell the index's number from the id's. The index now says 7 where the TEI and the id say 1.
  - **Scripts:**
    - `vite preview` listened on 4173 while `scripts/npm` published 5173;
    - on Linux without Node, `run dev` sent the API to `host.docker.internal`; it now shares the host's network;
    - the doctor took an empty `node_modules` volume for an install, and now looks inside it.

  The six refuted points:
  - the app's error pages lack its policy, but they are Hummingbird's plain 404s, with no page to protect;
  - client routes serve an `index.html` read at start, which differs only when `web/dist` is rebuilt under a running server, never in the image;
  - INSTALL's "History at State" is the kit's own name for the style;
  - PLAN's copy of the session rules records session 0's;
  - the missing log entry, which is this one.

**Delivered**

- **`scripts/npm`:** npm for `web/`.
  - It runs natively on Linux when Node at `web/.node-version`'s major is on PATH, as in CI after `setup-node` and in a cloud session. Otherwise, and always on a Mac, it runs in `node:22-bookworm-slim`, with `web/node_modules` in a Docker volume per checkout, since Linux builds of esbuild and Rollup cannot run on macOS.
  - `--playwright` runs `npx playwright test` in `mcr.microsoft.com/playwright` at the version the lockfile holds, and `--playwright-image` prints that image.
- **The server serves the SPA** (`WebClient`, `WebClientMiddleware`), from `FRUS_WEB_DIR`, which defaults to the image's `/usr/share/frus-light/web`.
  - A GET or HEAD outside `/api/` and `/reader/` gets a file of the build when there is one. Any other path whose last segment has no extension gets `index.html`, so a client route survives a reload. A missing script stays a 404, and an unknown API path keeps its problem details.
  - Every response of the app's carries its own policy: `default-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'`, with `nosniff` and `Referrer-Policy: no-referrer`.
  - Files under `/assets/` are cached as immutable for a year; everything else is `no-cache`.
  - Without a build at the default the server serves the API alone. A folder that `FRUS_WEB_DIR` names must hold one, or the server exits with status 2.
- **`GET /api/v1/volumes/{v}/documents/{d}/citation`:** the kit's formatter, as the app's Cite uses it, in `historyAtState` (the default), `chicago` or `turabian`.
  - It returns `citation` with the formatter's Markdown emphasis, and `plainText`, which is what Copy writes.
  - It also returns the canonical URL, the document number and label, and the styles with the kit's names for them.
  - The number is the index's; for a row with none, or with no index, it is the TEI's printed number. The response names its sources: `numberSource` for the number and `publicationYearSource: "manifest"` for the year.
- **`web/`:** React 19.3, TanStack Router 1.170 (code-based routes) and Query 5.104, Vite 8.3, TypeScript 6.0, Vitest 5 with jsdom, ESLint 10, and Playwright 1.63, with exact versions and a lockfile.
  - **The shell:** a skip link, the appearance (System, Light or Dark), a banner while no index is served, focus on each screen's heading, and the footer's notice that an instance is not an Office of the Historian service.
  - **Search:** the query box with a summary of the syntax; the document-type, date and front-matter filters, and volume chips; the exact count with its coverage; snippets whose `<b>` markers become `<mark>`, never markup from a string; and pages of 10 to 100, as far as the 7,500th result. Every search is a URL, in the server's form encoding.
  - **The reader:** a check of the page before the frame loads it, so an error shows as a notice; the server's page in an iframe sandboxed with `allow-scripts` alone; Previous and Next; text size; and Open on history.state.gov. A link inside the page shows a notice until S9b.
  - **The Cite rail:** the three styles, from the server, with the choice remembered; Copy Citation and Copy URL; and Close. Beside the text from 900 px wide, a sheet over it below that. Where the browser refuses the clipboard, the text is selected in a field.
  - `copy.ts` holds every string. ESLint forbids `dangerouslySetInnerHTML` and assignments to `innerHTML`.
- **The image:** a client stage on the build platform runs `npm ci` and `vite build`, and the runtime copies `dist` to `/usr/share/frus-light/web`. The server stage now copies only what it builds, and `.dockerignore` keeps everything else out.
- **`scripts/compose-smoke`:**
  - before the import, it checks that `/` and two client routes give the same `index.html` with the app's policy, that the app's script is immutable, and that a missing asset and an unknown API path are 404s;
  - `--e2e` runs `web/e2e` in the server's network namespace, so the app is at `http://localhost:8080`, a secure context, which the clipboard needs.
- **CI:**
  - a `web` job: `setup-node` at `web/.node-version`, then typecheck, lint, unit tests and the build, and a check that the Dockerfile's Node image is the same major;
  - the compose job runs `scripts/compose-smoke --e2e` and uploads Playwright's report when it fails;
  - `image.yml` builds on pull requests that touch `web/`.
- **`scripts/doctor`:** a Web section for the Node image, `web/node_modules` and the Playwright image. A missing Playwright image is a note, not a fix, since only `--e2e` needs it.
- **Docs:**
  - `INSTALL.md`: what phase 1 offers, and step 6, which becomes search, read and cite in the browser, with the API after it;
  - `SPEC.md`: the citation endpoint, how the SPA is served and cached, its policy, `FRUS_WEB_DIR`, and the reader frame's sandbox;
  - `PLAN.md` and its shared copy (rev 105): S9a and S9b;
  - `CLAUDE.md`: **rule 1 now names `scripts/npm` in place of `npm --prefix web`**, and the building notes add it and `--e2e`.
  - the README's status.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,701 tests pass, up from 1,693, with the one named skip, which CI's skip check allows. FRUSLightServerTests runs 61, up from 53: the citation route in each style, the number's three sources, the printer's name either side of 2014, and the app's files, client routes, policy, caching and HEAD, with what the fallback must leave alone.
- **The web app:** typecheck, lint, 26 unit tests in 7 files, and the build: `index.html` 0.5 KB, CSS 4.5 KB, and one script of 348 KB, 111 KB compressed, with no inline script and no source map.
- **The Compose smoke test with `--e2e`** passes on the local arm64 image, still 400 MB, since the app adds 364 KB:
  - before the import, `/` and two client routes give the same page with the app's policy, its script is immutable, and a missing asset and an unknown API path are 404s;
  - after it, Playwright 1.63 on Chromium, in `mcr.microsoft.com/playwright:v1.63.0-noble`, searches "treaties" and finds the two documents, their matches marked;
  - it opens frus1961-63v06 d1, focused at its heading, finds the document's text in the frame and the host script running there under the sandbox and the page's policy;
  - it opens Cite, which takes focus, chooses Chicago and copies the citation. The clipboard holds the API's `plainText`, which is the same text the Swift test holds;
  - Close hands focus back to the toggle, and Back returns to the results, focused at their heading. No console error or policy violation occurred in the page or the frame.

  That is S9's done-when.

**Notes**

- **The frame's origin.** The sandbox without `allow-same-origin` gives the reader's page an opaque origin, yet its policy's `'self'` still admits `/reader/host.js`, since `'self'` is the page's URL's origin. The browser suite checks that the host script ran inside the frame. The page's messages arrive with origin `null`, so the app accepts them by their source, the frame's window.
- **The clipboard** needs a secure context. `http://localhost` is one, but another machine's address over plain http is not, so the panel's fallback selects the text there. Phase 3's TLS proxy makes the clipboard work for a shared instance.
- **On a Mac,** `web/node_modules` lives in a Docker volume, so an editor's TypeScript service cannot see the packages. Running `npm ci` natively as well would give it a copy.
- **Not yet, for S9b:** Browse, the reader's links and the person and gloss cards, a keyboard-only path, and an axe check. Display titles, BibTeX and RIS wait for the phase-1 features' upstream pull request.

**Next: S9b.** Browse (the catalogue and a volume's reading order), the reader's links (`doc/` navigates, `person/` and `gloss/` open cards, `brokenref/` the Unresolved Reference sheet), a full keyboard path, and an axe check in the browser suite. Its done-when: Playwright browses to a volume, opens a document, follows a link inside it and opens a person card, by keyboard alone, with no axe violations.

## Session 8c: search, browse and the reader's page over the imported index

6 October 2026 · branch `claude/s8c-search-browse-reader`

S8's last pull request serves the endpoints over the kit's read-only stack, which S8b's pin move brought in, and runs check 3 through the API on the real Import path. That is S8's exit. The pin stays at `101e17d7`, and nothing upstream changed.

**How the session got there**

- **No new map.** S8's map at the start of S8a had designed these endpoints. S8b had confirmed every kit call they make at the pin: the read-only opens, the search service, the browse calls, `ReaderPage`, `reader(figureURL:)` and `FRUSURLScheme`. This session checked the rest against the source: the search result's fields, `document(forDocumentId:inVolume:)`, `datesByDocumentKey`, `effectiveIsEditorialNote` with `applyingClassificationOverride`, `FRUSCanonicalURL` and the parser's detailed result.
- **A review before the pull request opened.** Five reviewers and a skeptic per finding; 12 findings held, some found more than once, and all were fixed:
  - **A stack opened between an import's rename and the switch:** it could have opened the new file over the path and been kept as the old index's stack. `CorpusIndex` now records the file it opened (device and inode), and a stack whose path names another file is refused with a 503, which the next request retries.
  - **The smoke test's search check** depended on the JSON's key order, which varies from run to run.
  - **Two gaps in the tests:** the browse test now holds each list to the kit's reading order, and a synthetic test shows the index's classification reshaping a page.
  - **The records:** INSTALL's example `NEAR` was no proximity search; SPEC's security bullet still described three app scripts; the list of departures from the draft was incomplete; the claim of drift covered one script, not three; and a few sentences, here and in comments, were in the future tense or gave a wrong code.

  The six refuted points include a weak `If-None-Match` comparison, which this route's own weak tags make unnecessary, and links followed inside a figure folder, which the owner's own mounted folder holds.

**Delivered**

- **The served stack** (`ServedIndex`, `ServedIndexProvider`):
  - for each installed index, `FTS5Store(readingDatabaseAt:)`, `IndexingPipeline(readingIndexAt:…)` over the TEI folder, and a `SearchService`, opened off Swift's pool with `Blocking.run`;
  - built on the first request that needs it, shared by the requests after, and built again when an import installs a new index. Requests already holding the old stack finish on the file they opened, whose immutable connections keep reading it.
  - A route that needs an index answers 503 `INDEX_NOT_READY` until one is served, naming the readiness step.
  - A stack is refused, with a 503 the next request retries, when the path no longer names the file its `CorpusIndex` opened, as between an import's rename and the switch to the new index. `CorpusIndex` now records that file's device and inode.
- **`GET /api/v1/search`:** S8a's decoder, then the kit's exact `searchCount` and one page of `search`.
  - It returns `{total, countBasis: "exact", limit, offset, retainedLimit: 7500, items, coverage}`.
  - Each item has the draft's `SearchResult` fields, `bm25Score` among them, whose bits survive the JSON, and the kit's `isFrontMatter`, which the draft lacks.
  - A query with nothing left to search is 400 `EMPTY_QUERY`, carrying the kit's refusal, `emptyQuery`, as `searchError`.
  - Snippets keep the kit's `<b>` markers and are not escaped; a client escapes them.
- **`GET` and `POST /api/v1/search/inspect`:** what the kit compiles for the same parameters, the parse of the typed text with the structured fields, then each table's MATCH expression, in the keys of the parity harness's expression records.
  - A refused query is a 200 naming the refusal.
  - Before an import it compiles on a scratch index in the temporary folder, since compiling reads no index.
- **Browse:**
  - `GET /api/v1/volumes/{v}` adds the volume's structure, its front matter, chapters and back matter, when the index holds it.
  - `GET /api/v1/volumes/{v}/documents` lists the volume in reading order (`readingSequence`), with each entry's date and whether the index holds it, in pages of up to 1,000.
  - `GET /api/v1/volumes/{v}/documents/{d}` gives the document's metadata in place of the draft's render model, which the kit cannot encode: its effective classification, its canonical URL on history.state.gov, and its neighbours in reading order.
- **The reader's page,** by default from `…/html`, with `part=body` for the fragment alone:
  - `ReaderPage.build` in the draft's `colorScheme` and `textSize`, with `<script src="/reader/host.js" defer>` in its head;
  - figure images named by the server's address, through `reader(figureURL:)`;
  - when an index is served, its effective classification of the document reshapes the parse first, as the app's reader does;
  - a weak ETag of the rendering version and the page's bytes, with 304 for `If-None-Match`;
  - a policy that loads nothing from elsewhere and runs only the host script and the figure handler, which it allows by its SHA-256.
- **`GET /api/v1/volumes/{v}/figures/{file}`:** a `.png` from `<volume>.figures/` beside the TEI, where FRUS Explorer keeps a volume's figures. A volume outside the manifest is 404 `VOLUME_NOT_FOUND`. A name that is not a single safe path component (`FRUSURLScheme.isSafeComponent`), or not a `.png`, or a missing file, is 404 `FIGURE_NOT_FOUND`.
- **`GET /reader/host.js`:** the web's stand-in for the app's WebKit host. It gives the three message handlers the app's reader scripts post to, and handles the reader's `frusexplorer://` links. Each becomes a message to the parent page.
- **`scripts/compose-smoke`,** after the import: a search finding the synthetic export's two documents, a document's page with its host script and policy, and the host script.
- **Docs:**
  - `INSTALL.md`: what phase 1 offers, and step 6, search and read;
  - `SPEC.md`:
    - Reader rendering's steps, among them that `frus-print.css` is for collection exports, and that the Resources copy of `frus-highlights.js` has drifted from the script the app injects;
    - the reader page's own content security policy;
    - the exact count with the 7,500 retained;
    - the draft's retired `/subjects` struck from the API table;
    - where the API departs from the draft;
  - `COORDINATION.md` and the README.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,693 tests pass, up from 1,675, with the one named skip, which CI's skip check allows. FRUSLightServerTests runs 53, up from 38, and FRUSParityTests 98, up from 95. The run printed:
  - "check 3 through the API: 482 queries, 482 identical and 0 reordered only within Mac tie groups, every record the kit's own; 482 compiled as the golden file says, 43 refused; the live index unchanged";
  - "check 4 through the page: 392 of 392 rows identical, 8 figure images in 2 rows named by the server; one head for every page";
  - "browse through the API: 3 volumes of 553 indexed, 139 of 140, 123 of 128, 130 of 134 entries in reading order held by the index", each list the kit's reading order;
  - checks 2 to 4 in process, as at the pin move.

  The kit's fixture index is dropped into the drop zone as a copy, imported, checked and installed. It is then served through the read-only open, and every query is read over HTTP with the golden tool's results loop. Check 3 passes through the API: S8's exit.
- **The Compose smoke test** passes on the local arm64 image: after the import, a search finds the synthetic export's two documents, and frus1961-63v06 d1's page, 21,837 bytes, comes with its host script and policy.

**Notes**

- **One stack for every request.** The pipeline is one actor on one connection, so searches, counts and browse calls take turns, and its SQLite runs on Swift's cooperative pool, as a volume's parse does (S8a). That suits one user. Check 12's load target needs a pool of stacks over the same immutable file, and parsing moved off the pool.
- **Not yet:**
  - **Facets, date sort and the full inspector:** the kit's facets are internal, and the app's date order and Query Inspector are app code.
  - **The reader's own scripts:** `kOffsetEngineJS` and the others are app constants.
  - **The publication year a citation takes from the TEI:** app code.

  All of these wait for the phase-1 features' upstream pull request. Persons, terms and cross-references wait for S9 or later.
- **The fixtures cannot show the classification override.** Every fixture document's classification in the index is its TEI's, so check 4 through the page shows only that the override changes nothing where nothing is overridden. A synthetic server test marks a document as an editorial note in the served index and finds its page reshaped as one.

**Next.**
- S9: the browser app for phase 1, Browse, Search, the reader and Cite, over these endpoints. Cite needs a citation endpoint (the kit's formatter is public; the TEI's publication year is app code).
- The phase-1 features' upstream pull request: the reader's scripts, the publication year, facets, the inspector, date order, display titles, and BibTeX and RIS. It is timed so its pin move comes just before the full export for S10.
- A web session adds the daily watch of the app's `v2`.

## Session 8b: pin move to the read-only open and the reader's page

6 October 2026 · branch `claude/pin-101e17d` · upstream [joshbotts/FRUS-Explorer#1575](https://github.com/joshbotts/FRUS-Explorer/pull/1575) (merged as `101e17d7`)

S8a's upstream pull request merged on `v2` as `101e17d7`, directly after the old pin. This pull request moves the pin there (rule 5). That brings the kit's read-only open, a host's figure addresses and the reader's page into this repository's build. It remakes the golden files from the owner's new export, and tests the read-only open on the fixture index on Linux. The index version (65), the FTS generation (4) and the app's build (49) are unchanged, so the server, the image, `compose.yaml` and `docs/INSTALL.md` are too.

**How the session got there**

- **A map first.** Three readers mapped the records and line citations the move makes stale, the build and the Mac-side tools, and the tests. The build side needed one change. #1575's two new suites hash with CryptoKit, which is swift-crypto's Crypto on Linux. `tools/mac-golden`, `CompatibilityTests` and CI's skip check needed nothing. The app's `HTMLTemplate.build` keeps its signature and forwards to the kit's page, and the new suites have no skip traits.
- **A review before the pull request opened.** Four reviewers and a skeptic per finding; three findings held, one found twice, and all were fixed:
  - the read-only tests took the file's baseline after opening it, so a write made while opening would have passed; the baseline is now the file as copied, checked again once the connections close;
  - the tests compared the compiled expressions, which read no index, as evidence about the read-only connection; that comparison is gone;
  - one sentence of this entry.

  The map also found that the writable index's 482 queries ran twice per process; `FixtureIndex.results()` now runs them once, for check 3 and the read-only comparison.

**Delivered**

- **The pin, `101e17d7`,** and `Package.swift`: FRUSCoreKitTests gains Crypto on Linux. FRUSCoreKitTests runs 884 tests in 118 suites, up from 878 in 116.
- **The golden files,** remade by `scripts/make-golden --export` from the owner's export (below):
  - **All 392 rows' HTML** are byte for byte as before, and so are the expressions and the results. Only the provenance changed.
  - **The index summary's 36 gating digests and 7 checks** are the same. Four information fields changed, none of them compared:
    - the export's stamp;
    - the timings;
    - `volume_structures`' JSON key order, already information because the app writes those keys unsorted;
    - the AUTOINCREMENT counters, which about doubled because the library's tables were emptied and filled again.

  So the reader's page moving into the kit, and the figure case beside `.reader`, changed nothing the app writes.
- **The read-only open on the fixture index** (`ReadOnlyOpenTests`, 3 tests). A copy of the kit's fixture index in rollback-journal mode, alone in a folder as `/data/index/frus.db` is, is opened through `FTS5Store(readingDatabaseAt:)` and `IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:)`:
  - **Search:** all 482 queries' counts, first 50 results and tie tails, score bits included, are the writable index's. So the read-only connection runs every query as the writable one does, the `=exact` queries among them, which need `frus_exact_word` registered on it.
  - **Browse:** each volume's documents, reading order and cached structure are the writable index's.
  - **Writes:** a write is refused by SQLite as read-only, code 8, with the fixtures' TEI in reach, so the refusal is not a missing volume's.
  - **The file:** it is as it was copied, before anything opened it: the same SHA-256, only `frus.db` in its folder, and header bytes 18 and 19 still 1. Each test checks that after its connections close, and the search test while they are open too.
- **What #1575 gives the reader** (`ReaderPageParityTests`, 3 tests), on all 392 golden rows along the server's full-parse path:
  - `reader(figureURL:)` given the app's own addresses writes `.reader`'s bytes.
  - A host's addresses change exactly the 8 image sources, 7 in frus1969-76ve09p1's d87 and 1 in d116. Mapped back, every row is the golden file's.
  - `ReaderPage.build` holds each row's golden fragment between its one `<body>\n` and `\n</body>\n</html>`, after one head shared by every document. Dark and extra large change the head only.
- **The harness:** `ReaderRenderer.fullParsePass` takes what writes each document, the reader's fragment by default.
- **Records:**
  - five line citations of `IndexingPipeline.swift`, which #1575 moved: four in the harness's comments and SPEC's `setupDatabase` range;
  - `COORDINATION.md`: the pin, the test counts, the read-only open and #1575's pin move;
  - `PLAN.md` and its shared copy (rev 104): the Golden files checkpoint and the risk row;
  - `SPEC.md`'s compatibility contract;
  - the prep note;
  - `Package.swift`'s comments.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,675 tests pass, up from 1,663, with the one named skip, which CI's skip check allows. FRUSCoreKitTests runs 884, and FRUSParityTests 95, up from 89; the other targets are unchanged. Against the new golden files the run printed:
  - "check 2 passes: 36 digests and 7 checks are the Mac's";
  - "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups; 359 with other score bits (information)";
  - "check 3's expressions: 482 of 482 queries compile as the golden file says, 25 of them outside the default scope; 43 refused";
  - "check 4, the reader's path: 392 of 392 rows identical", and so along the full-parse path and through the API;
  - "the read-only open: 482 queries' results are the writable index's, score bits included; 43 refused by both; the file is as it was copied";
  - "a host's figure addresses: 8 images in 2 rows; mapped back, 392 of 392 rows identical";
  - "the reader's page: 392 of 392 rows' bodies identical, one head for every document".
- **The Compose smoke test** passes on the local arm64 image, built at the new pin.
- **The first run at the new pin** overlapped `make-golden`. Its only failures were three staleness checks on the files made from the export, which had not been rewritten yet, and FRUSCoreKitTests' 884 tests passed, none skipped.

**The owner's export**

Made on 6 October from a build of `101e17d7` after Erase Everything…, and checked in S8a's entry: build 49, index version 65 and FTS generation 4, with none of the owner's writing, the three fixtures only, and no log or journal beside it. `make-golden` copied it to a temporary folder and worked on the copy alone.

**Notes**

- **The tools still cannot tell exports of `f69b4a0a` and `101e17d7` apart:** their build and index version are the same. Only the procedure, and `exported_at`, distinguish them.
- **Left to S8c,** which serves the full page: SPEC's Reader rendering steps 2 and 6, which still name `HTMLTemplate` and `FRUSTheme.cssVariables`, now the app's forwarders to `ReaderPage`.

**Next.**
- S8c: search, browse and the reader's full page over the read-only stack, with figures by the server's own address, and check 3 through the API on the real Import path.
- A web session adds the daily watch of the app's `v2`.

## Session 8a: the read-only open upstream, and the server links the kit

6 October 2026 · branch `claude/s8-search-reader-api` · upstream [joshbotts/FRUS-Explorer#1575](https://github.com/joshbotts/FRUS-Explorer/pull/1575) (merged as `101e17d7`)

S8 serves search, browse and the reader over the imported index. A map at the start found that it cannot do so at the pin: every kit opener writes to the database it opens. `FTS5Connection` switches the file to write-ahead logging, and `IndexingPipeline`'s set-up runs schema statements and four writes that throw on a read-only connection. Pointed at `/data/index/frus.db`, the kit would rewrite the file under the server's immutable reader and leave `-wal` and `-shm` files beside it. So S8 became three pull requests. This session opened S8a's upstream pull request, which the owner checked and merged. It also built the web groundwork that needs no new upstream API, at the old pin `f69b4a0a`.

**The owner's decisions, 6 October**

- **Split:** S8a (the upstream pull request, plus web groundwork at the old pin), S8b (the pin move, with a new three-volume export) and S8c (the endpoints, with check 3 through the API).
- **Upstream scope:** the read-only opens, the reader's page and the host's figure addresses. The reader's scripts, the publication year, facets, the inspector, date order, display titles and BibTeX and RIS wait for a later upstream pull request of phase-1 features.
- **API shape:** the draft, extended where the Mac needs more (`PLAN.md`, Answered on 6 October).
- **Check 3:** through the real Import path. The kit's fixture index goes in as an unstamped copy, and is searched through the read-only open.

**How the session got there**

- **A map first.** Five readers mapped the API contract, the server, the kit's search and browse, the rendering, and parity through the API, and a sixth synthesized the plan and the four decisions above. Three of their claims did not hold:
  - **`+` in a query string.** Hummingbird's `uri.queryParameters` leaves `+` as it is, but a browser's `URLSearchParams` writes a space as `+`. The server reads the raw query with form semantics instead.
  - **`frus-print.css`.** The app loads it for collection exports only, not in the reader, as SPEC's Reader rendering step 3 says.
  - **The 7,500 cap.** It limits only how many results the app keeps. The count is exact, so SPEC's "at least 7,500" does not match the Mac.

  S8c corrects SPEC for the last two.
- **A review before the upstream pull request opened.** Four reviewers and a skeptic per finding; 11 findings held and all were fixed. Among them:
  - the test of the pipeline's refusal of a missing file passed without reaching the pipeline;
  - one refusal message was wrong;
  - three doc sentences claimed more than the code does.
- **A review before this pull request opened.** Four reviewers and a skeptic per finding; 12 of 21 findings held, all fixed:
  - the log named `Blocking.run` as the way to move parses off Swift's pool, which it cannot do (Notes);
  - the date check took a digit carrying a combining mark as a digit;
  - `/api/v1/status` took parameters it ignores;
  - the image copied the data files with the checkout's modes, which a strict umask would make unreadable to the server's user;
  - no test reached the route's lookups, the cache's order, an unparseable volume, or the middleware's 500;
  - six sentences in the records and comments.
- **One mistake.** Text holding backticks went through an unquoted heredoc, and the shell ran the backticked commands, among them a Linux build and test run in this worktree. The session stopped them, confirmed that both checkouts were clean and that nothing was left running, and wrote the pull request's description with a file instead. Text with backticks now goes only through quoted heredocs or files.

**The upstream pull request**

Branch `claude/web-readonly-reader-page`, from `v2` at `f69b4a0a`: seven commits in review order. Its description holds the Mac check's commands and expected results.

- **`FTS5Store(readingDatabaseAt:)`** opens `file:…?mode=ro&immutable=1` read-only. It checks the FTS generation and both tables, and sets only the busy timeout, in-memory temporary tables and the cache sizes. It never sets the journal mode.
- **`IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:)`** opens the same way. It skips `setupDatabase`, the cache-insert statement and the iOS memory observer, and still registers `frus_exact_word`, without which every `=exact` query breaks. `isReadOnly` says which open made a pipeline.
- **Figures:** `FigureImages.linked(url:)` writes the reader's markup with the host's address, and `FRUSRenderNodeHTMLSerializer.reader(figureURL:)` wraps it. `FRUSURLScheme.figureURL(for:)` and `isSafeComponent(_:)` are public.
- **The reader's page** moved into `FRUSCoreKit/TEI/ReaderPage.swift`: `ReaderPage.build(model:appearance:textSize:serializer:head:)`, its CSS, and `ReaderAppearance`. `TextSizePreference` moved too, keeping its name. `HTMLTemplate` and `FRUSTheme` forward to them.
- **Tests:**
  - `IndexReadOnlyOpenTests`: nine queries answer read-only exactly as read-write, score bits included. The index browses, refuses a write, and keeps the same bytes with nothing beside it.
  - `ReaderPageTests` pins the SHA-256 of the page's head for both appearances and all four text sizes, recorded from `v2`'s `HTMLTemplate.build` before the move.
  - FRUSCoreKitTests goes from 878 tests in 116 suites to 884 in 118.

**Results at its head**

- **Linux,** in a scratch checkout with the branch in its submodule folder:
  - "✔ Test run with 884 tests in 118 suites passed", none skipped;
  - the read-only open answers as the writable one, on macOS too;
  - this repository's harness failed only its staleness checks.
- **`tools/mac-golden`,** built against the branch, wrote the HTML of all 392 rows and the expressions of all 482 queries byte-identical to the committed golden files. Only their provenance changed.
- **macOS and iOS**, which the upstream description gives in full:
  - both Mac builds have the same five warning lines;
  - the normalized symbol diff is 14 removed and 92 added, each name explained;
  - the full unit run gives 6,505 tests in 767 suites, failing only the 8 Keychain tests an unsigned build fails, against `v2`'s 6,498 in 765;
  - `swift test` gives 38 runs and 2,547 tests, all passed.

The owner ran the Mac check, and #1575 merged on `v2` as `101e17d7`, directly after `f69b4a0a`.

**Delivered in this repository** (at `f69b4a0a`)

- **`FRUSLightAPI`,** a new library target, holds the HTTP application. It depends on FRUSLightCore, FRUSCoreKit, FTS5Store, Hummingbird, swift-service-lifecycle and swift-log. FRUSLightServer keeps the command line, the configuration from the environment and the health check, and FRUSLightCore still links no kit.
- **The app's data files.**
  - **The setting:** `FRUS_RESOURCES_DIR`, by default `/usr/share/frus-light/resources`, where the image copies `FRUSExplorer/Resources` whole. `scripts/swift` points it at the submodule's folder.
  - **The load:** `ServerResources` reads the manifest through the kit's `FixedVolumeCatalogue`, the broken-refs index and `IndexingResources.loading(fromDirectory:)`, once at start. A folder lacking any of the five files it needs stops the server with exit status 2, naming them, before anything is written.
- **Problem details.** `APIProblem` answers RFC 9457 `application/problem+json`: `{type: "about:blank", title, status, detail, instance, code, searchError?}`. A middleware gives every error under `/api/` that shape, including a path no route matches; an unexpected error is logged and answered as a 500 that names nothing internal.
- **The catalogue.** `GET /api/v1/volumes` takes the draft's `status`, `subseries`, `limit` and `offset`, with pages of up to 1,000 so one request lists all 553. `GET /api/v1/volumes/{v}` returns the draft's fields, written by the server rather than by the kit's `Encodable`, which would add the app's `provenance`. Each volume says whether the index holds it, how many of its documents, and whether its TEI is in the mounted folder. The list carries `coverage`: indexed volumes and documents, the 553 manifest volumes and the index version. `CorpusIndex` now counts documents per volume when it opens.
- **The reader's body.** `GET /api/v1/volumes/{v}/documents/{d}/html?part=body` renders through check 4's full-parse path:
  - `ReaderService`, an actor, parses each volume once with `parseVolumeFull` and keeps the four most recent. A volume whose file changes size or modification time is parsed again, and requests for a volume being parsed wait for that parse.
  - Each document renders with the reader's lookups, the converter with the bundled broken-refs index, and the `.reader` serializer.
  - It needs no index, so it answers before an import. Only a manifest id is ever joined into a path.
  - A volume that will not parse is a 500 `TEI_UNREADABLE`, and is not kept, so the repaired file renders.
  - The response is `text/html; charset=utf-8`, with `X-FRUS-Rendering-Version`, a content security policy that runs no script, `nosniff` and `no-referrer`.
  - The errors are 404 `VOLUME_NOT_FOUND`, `TEI_NOT_AVAILABLE` and `DOCUMENT_NOT_FOUND`. Without `part=body` the answer is 501 `PAGE_NOT_AVAILABLE`, since the full page needs #1575's `ReaderPage`.
- **The search request.** `SearchRequest(formEncoded:)` turns a query string into the kit's `SearchParameters`, a limit and an offset, for S8c's `GET /search`:
  - form semantics, through `FormQuery`, refusing malformed escapes and bytes that are not UTF-8;
  - thirteen names for twelve fields, `keywords` passed on exactly as typed;
  - a list is its name repeated, and one empty value is the empty list, which keeps `yearKeys: []` (matches nothing) apart from no filter;
  - a date bound may be empty, so an open range has a form;
  - `limit` 1 to 100, and `offset + limit` within 7,500;
  - the draft's `facets`, `booleanMode`, `subjectTagIds` and `personRef` are refused until they arrive, and so is any unknown name.
- **The image.**
  - The runtime stage installs `libxml2`: the static binary links FoundationXML's libxml2 dynamically, and the first smoke run failed at start without it.
  - It copies the data files and sets `MALLOC_ARENA_MAX=2` (Notes).
  - The image is 399 MB on arm64, up from 251 MB:
    - the data files are 52 MB;
    - libxml2 and ICU are about 38 MB;
    - the stripped binary is 73 MB.
- **`scripts/compose-smoke`,** before the import, checks:
  - the catalogue's 553 volumes;
  - a document rendered from the mounted fixtures;
  - problem details for an unknown volume.
- **Docs:**
  - `INSTALL.md`: what phase 1 offers, the image size, memory, the TEI folder, and a new step 6 to read a document;
  - `SPEC.md`: the setting, and two conventions, problem details and query strings;
  - `PLAN.md` and its shared copy (rev 102): S8's three rows, Mac check 4, the decisions, the risk and memory rows;
  - `COORDINATION.md`: the server links the kit, and #1575's part;
  - `compose.yaml`, the prep note and three comments.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,663 tests pass, up from 1,631, with the one named skip, which CI's skip check allows. Checks 2 to 4 pass as at the pin move.
  - FRUSLightServerTests runs 38 tests, up from 9. FRUSParityTests runs 89, up from 86.
  - "check 4 through the API: 392 of 392 rows identical": every golden row, fetched from the reader's route with the fixtures in the TEI folder, is the golden file's bytes. The three volumes are parsed once each.
  - "check 3 through the API: all 482 queries decode into the Mac's SearchParameters, in both encodings". Every parity query is written as a strict client and as `URLSearchParams` would write it. Each decodes into exactly what `LinuxSearch.parameters` builds, which mirrors `tools/mac-golden`, and its text keeps the same UTF-8 bytes. Since `matchExpressions(for:)` depends on those parameters alone, the search S8c serves compiles every query as the golden file says.
- **The Compose smoke test** passes on the local arm64 image.
- **The reader on real volumes,** from a HistoryAtState clone mounted read-only into the image:
  - the first document of a 12 MB volume takes about 0.55 s, the parse;
  - another document of a parsed volume takes 6 ms.
- **PR #22's CI, on amd64,** for the record: check 2 passes; check 3's results show 482 identical, with 366 queries' scores in other bits than the Mac's, where arm64 had 359.

**The owner's export for S8b**

The owner built `101e17d7`, ran Erase Everything…, downloaded the three fixture volumes and exported with notes, summaries and tags off. Its stamp, read through SQLite's immutable mode:
- `exported_at` 2026-10-06T04:31:35Z, after the merge (04:15:56Z);
- build 49, index version 65 and FTS generation 4, with none of the owner's writing;
- exactly the three fixtures, 139, 123 and 130 documents, with every revision at index version 65;
- no log or journal beside it.

**Notes**

- **Memory.** Reading across the 16 largest manifest volumes, about 11–13 MB each:
  - With glibc's default arenas, the process grew from 7 MB to 221 MB in one pass, and to 303 MB in three.
  - With `MALLOC_ARENA_MAX=2` it reached 127 MB in one pass, and held near 142 MB and then 166 MB over eight.
  - That is the allocator keeping freed parses in per-thread arenas, not a leak: the cache keeps four volumes, and a test shows it parses an evicted volume again. The image sets two arenas.
- **A parse blocks one of Swift's cooperative threads** for about half a second on a large volume, since `XMLParser` runs synchronously inside the kit's parser actor. That is acceptable for one user. Before check 12's load target, parsing should leave the pool. `Blocking.run` cannot move it, since it takes a synchronous closure and the kit's parse entry points are all async methods of that actor. Two ways can:
  - run the parse under `withTaskExecutorPreference` with an executor the server owns, which a default actor follows (SE-0417);
  - or have upstream add a synchronous parse entry point.

  Either way the server should then limit parses in flight to one or two. Today the pool's width is the only limit, and the cache bounds only finished volumes.
- **The body's figure images** keep the reader's `frusexplorer://figure/` addresses, as the golden files do. S8c serves them by the server's own address, through #1575's `.linked` case.
- **A TEI file cut short** rendered its first document with no error on Linux, where the kit's parser does not report the early end. A file still being copied into the TEI folder is parsed again when its size changes, so this matters only for a file left cut short.
- **Not changed:** the index version and the app build, so `Compatibility.swift` and the export contract are unchanged.

**Next.**
- S8b: the pin move to `101e17d7`, with golden files from the owner's export above, the Crypto dependency FRUSCoreKitTests gains on Linux, and the read-only open tested on the fixture index.
- S8c: search, browse and the reader's full page over the read-only stack, with check 3 through the API on the real Import path.
- A web session adds the daily watch of the app's `v2`.

## Pin move: FRUSCoreKit, part 2, on Linux in CI

5 October 2026 · branch `claude/pin-f69b4a0` · upstream [joshbotts/FRUS-Explorer#1573](https://github.com/joshbotts/FRUS-Explorer/pull/1573) (merged as `2d216f4c`) and [joshbotts/FRUS-Explorer#1574](https://github.com/joshbotts/FRUS-Explorer/pull/1574) (merged as `f69b4a0a`)

Both of S6's upstream pull requests merged after the owner's Mac checks. This pull request moves the pin from `af8bedab` to `f69b4a0a`, `v2`'s head. That puts FRUSCoreKit's indexer, search and citation matcher into this repository's build. CI now runs checks 2 and 3 on the fixtures through the kit's public API alone, as the server will use it. The index version (65), the FTS generation (4) and the app's build (49) are unchanged, so the server, the image, `compose.yaml` and `docs/INSTALL.md` are too.

**How the session got there**

- **A map first.** Three readers mapped the build and CI, checks 2 and 3 as tests, and the records and the export. A fourth synthesized the plan.
- **A review after the draft opened.** Five reviewers looked at five things: correctness, CI and the build, the parity rules and the golden files, the records, and the Mac-side tools. A skeptic checked each finding. Four of the twelve held, all fixed before the export:
  - `COORDINATION.md` still called #1574 open;
  - `PLAN.md`'s Golden files checkpoint still said Done;
  - two prep notes still said the TEI hash comparison waits for S6;
  - the skip check anchored skips but not cancellations.

  Three refuted points were cheap enough to take anyway: a citation's line order, `frus-parity index` naming a volume twice, and `IndexCopy` leaving a partial file behind.
- **Two findings shaped the work:**
  - **CI's skip check.** It would have failed at the new pin on the passing test "A Lot File(s) prefix is skipped, never captured into the key".
  - **The export.** The owner's export must be made again after Erase Everything…. With the index version unchanged, a build of the new pin does not re-index the three volumes an earlier build indexed, so an export taken without erasing would still hold the old build's index.

**Delivered**

- **The pin and `Package.swift`.**
  - FRUSCoreKit depends on FTS5Store, with CSQLite on Linux and upstream's sqlite3 link on macOS.
  - FRUSCoreKitTests adds FTS5Store, SourceNoteKit and CSQLite.
  - FRUSParityTests adds FRUSCoreKit.
- **CI's skip check** now matches a skip or a cancellation by its verb right after the test's or suite's name, and still matches XCTest's `Test Case '…' skipped (` line. I ran the step itself with GNU grep in the container, with `LANG` unset and set to `C.UTF-8`:
  - it passes the full Linux log, with the named skip once;
  - it passes that log with passing tests whose names say "skipped" or "was cancelled";
  - it fails a log with nine planted skip and cancel lines, all nine reported.
- **The harness** (`Tests/FRUSParity`):
  - `ParityIndex` indexes TEI volumes with the kit's pipeline. It loads the data files with `IndexingResources.loading(fromDirectory:)` over the submodule's `FRUSExplorer/Resources`, keeps stamps in memory, and runs `runPostIndexPasses`.
  - `IndexCopy` copies a live index with the backup API, reading it through the normal pager, then takes the copy out of write-ahead-log mode for the summary.
  - `LinuxSearch` runs the query list's results and compiled expressions.
  - `ResultsLoop`, in ParityFormat, is the results loop. `tools/mac-golden` now runs the same code.
  - `ParseParity.recordMismatches` compares the compiled expressions in every scope.
  - `GoldenValidation.load` reads one golden file for a check.
- **The CI tests** (FRUSParityTests, 76 → 86 tests in 14 suites). The fixtures are indexed once per test process, from a copy of `fixtures/tei`.
  - **Check 2:** the summary of the kit's index against the golden summary. While that file is pending, the test still checks that:
    - every check is at its right value;
    - the person rollup is rebuilt;
    - each volume's documents match the render golden's (139, 123 and 130).
  - **Check 3's results:** all 482 queries against the golden results.
  - **Check 3's expressions:** every query, the 25 outside the default scope among them. Until now Linux compared only the default scope's expressions, by inference from the parse.
  - **The four data files:** present, and each decodes. Check 2 cannot show the broken-references index, since it flags nothing in the fixtures.
  - **The copied mapping** from query to search parameters, field by field.
  - **The results loop**, `measureDocuments` and `recordMismatches`.
- **`frus-parity index`** indexes the fixtures, or any folder of volumes, with the kit. With `--metrics` it prints the timings and peak memory; with `--out` it keeps a copy for `summarize`.
- **The golden files.**
  - `scripts/make-golden`, run without an export, rebuilt `tools/mac-golden` against the new pin. Only the provenance of the render manifest and the expressions changed: all 392 rows' HTML and all 482 queries' expressions are byte for byte as before.
  - The index summary and the results, from the owner's new export (below). Until it arrived they waited in `fixtures/golden/PENDING`, and the pull request stayed a draft.
- **`fixtures/sample`:** 24 volumes' names and SHA-256 sums at HistoryAtState/frus `8e5da08c`, for measuring. No TEI is committed.
- **Docs.**
  - `SPEC.md`: the table definitions' new place, and the measurements under Sizing.
  - `PLAN.md` and its shared copy (rev 90): Mac check 3 and the Golden files checkpoint done, the risk rows, the export note.
  - `COORDINATION.md`, the prep notes, the README, `CLAUDE.md` and `scripts/make-golden`'s export steps.
  - The comments that waited for session 6, and four line citations of `IndexingPipeline.swift`.

**Results**

- **Linux, `swift:6.4-noble`, arm64:** all 1,631 tests pass, with the one named skip. FRUSCoreKitTests runs 878, up from 393, and FRUSParityTests 86, up from 76; the other targets are unchanged.
- **Checks 2 and 3,** against the new export's golden files: both pass (below). Before the export arrived, the comparisons also passed against the 4 October files (made from a build of `af8bedab`, restored for that run), and only their staleness checks failed.
- **Check 3's expressions:** "482 of 482 queries compile as the golden file says, 25 of them outside the default scope; 43 refused".
- **The refactored `tools/mac-golden`** runs the shared loop. Built against the new pin and run over the 4 October export, which its checks still accept at an unchanged build and index version, it writes all 482 records identical to the committed results, score bits included.
- **Indexing, a release build:**
  - **Setup:** Docker Desktop with 10 CPUs and 7.7 GiB.
  - **Fixtures:** three runs. The three volumes and the passes after indexing take 1.06, 1.07 and 1.10 s, at a peak of 128–130 MiB.
  - **Sample:** the 24 volumes (165 MB, 13,425 documents) index in 24.5 s, about 550 documents a second, at a peak of 136 MiB, into a 141 MB index. The passes after indexing take 0.6 s of that.
  - **Limited to 4 CPUs:** 24.6 s, peaking at 140 MiB, because volumes are indexed one at a time.
  - **Scaled by size:** the 3.34 GB corpus would take about 8 minutes and make about 2.9 GB, which is the Mac's full export's size.
  - **Caveats:** the first volume's time includes decoding the data files; the peak is the whole process's; the rollup's cost at full size is not known.

**The owner's export**

The owner built `f69b4a0a`, ran Erase Everything…, downloaded only the three fixture volumes, waited for indexing and the person rollup, and exported with notes, summaries and tags off. Its stamp, read through SQLite's immutable mode:
- `exported_at` is 2026-10-06T01:34:52Z, after the pin's commit (2026-10-05T10:46:10Z);
- build 49, index version 65 and FTS generation 4, with none of the owner's writing;
- exactly the three fixtures, 139, 123 and 130 documents;
- no log or journal beside it.

`scripts/make-golden --export` wrote both files and emptied `PENDING`, and `check-golden` passes. Against the 4 October export's files, the new export changes nothing that is compared:
- all 36 gating digests and 7 checks are the same;
- all 482 result records are the same, score bits included;
- only the provenance, the export date and the history-dependent information fields differ.

The full Linux suite then printed:
- "check 2 passes: 36 digests and 7 checks are the Mac's";
- "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups; 359 with other score bits (information)";
- "check 3's expressions: 482 of 482 queries compile as the golden file says, 25 of them outside the default scope; 43 refused";
- "check 4, the reader's path: 392 of 392 rows identical", and so along the full-parse path.

Checks 2 to 4 pass on the three fixture volumes, with indexing speed and memory recorded: phase 0's exit.

**Notes**

- **The tools cannot tell an `af8bedab` export from an `f69b4a0a` one,** because the build and index version are the same. Only the procedure, and `exported_at`, distinguish them.
- **The query mapping stays copied** between `tools/mac-golden` (the app's `SearchParameters`) and `LinuxSearch` (the kit's). A Linux test pins the Linux side, field by field.
- **Not changed:**
  - the Settings row in `PLAN.md` and its open question about the container runtime, which are the owner's to close;
  - `docs/INSTALL.md`, since the image compiles no kit.

**Next.**
- S8: search, browse and document-render endpoints over the imported index. It needs its own upstream pull request first, for a read-only pipeline open, the figure URLs and the page shell.
- A web session adds the daily watch of the app's `v2`.

## Session 6b: FRUSCoreKit, part 2, upstream pull request B

5 October 2026 · branch `claude/s6b-citation-lookup` · upstream [joshbotts/FRUS-Explorer#1574](https://github.com/joshbotts/FRUS-Explorer/pull/1574)

The owner's Mac check 3 passed for #1573, and it merged on `v2` as `2d216f4c`. S6's second upstream pull request branches from that merge. It moves Citation Lookup's matcher into `FRUSCoreKit/`, with its block splitter, its page-range store and what their suites use, so check 7's matcher half can run on Linux. As with S6a, this entry records the results at the pull request's head. The pin stays at `af8bedab` until the pin move that follows this merge. This repository's pull request is records only, and passes CI at that pin.

**Decided in the session**

The owner's 4 October answers covered this pull request's shape. Two smaller decisions were the session's:
- **Check 7's matcher count is 70, not 74.** `PLAN.md` took 74 from the whole file `CitationMatchingEngineTests.swift`. Four of its tests can run only in the app. One builds the app's `AppState`, one dispatches through the WebKit link handler, and two read the app's views' source. They stay Xcode's, guarded with their reasons. Rewriting the handler test for Linux would copy the handler's code, which rule 4 forbids. `PLAN.md` now says 70 of 74.
- **Only the seam is new public API.** The engine and `PageRangeStore` were already public. Batch and Structured Entry's types (the splitter, the batch outcome and row, the form's fields) stay internal until the web edition's citation lookup needs them, in phase 2, under the owner's rule that only what S6's checks need becomes public.

**How the session got there**

- **A map first.** Three readers mapped the source closure, the tests, and the scans and records at `2d216f4c`, and a fourth synthesized the plan. The one app name the moved code used was `ManifestStore`, read for one property, `citableEntries`. None of the files had changed since `af8bedab`, so the S6 map's line numbers held.
- **A review before the pull request opened.** Five reviewers looked at five things: behaviour preservation, the tests, the records, the source scans and audits, and this repository's side. A skeptic checked each finding. Three of the reviewers found nothing. One finding held: a commit message said the page-range store bound page numbers as text, when it binds only volume ids. The message was corrected before the first push. The four findings about this repository were real, but none is a defect of the upstream pull request. They are this pull request's records and the pin move's work, both below.

**The upstream pull request**

Branch `claude/fruscorekit-part2b`: eight commits in review order. Its description lists them and holds the Mac check 3 commands, the expected results and the symbol-diff script. This time the script is written to `/tmp/symdiff.py` by the command block itself, and `v2` is built from a worktree beside the checkout, so the checkout never leaves the branch. Both changes answer what went wrong in #1573's check.

- **Moves.**
  - Four files by `git mv`:
    - `CitationMatchingEngine`, with `ConfidenceLabels`;
    - `CitationBlockSplitter`, with the batch outcome, row and runner;
    - `PageRangeStore`;
    - `CountCopy`, with `StatusBarCopy`.
  - `CitationLookupFields` and `CollectionCitationLineResolver` moved verbatim out of their SwiftUI files.
  - The kit goes from 29,223 lines in 40 files to 31,887 in 47.
- **The seam** (`FRUSCoreKit/Citation/CitableVolumeCatalogue.swift`):
  - `CitableVolumeCatalogue` has one requirement, `var citableEntries: [VolumeManifestEntry] { get async }`, and the engine holds `any CitableVolumeCatalogue`.
  - The app conforms `ManifestStore` with an empty extension. Its main-actor getter witnesses the requirement, so each read still hops to the main actor.
  - `FixedVolumeCatalogue(contentsOf:)` decodes a `manifest.json`. The server will pass one made from the submodule's `FRUSExplorer/Resources/manifest.json`.
  - The initialisers keep the label `manifestStore:`, so no caller changed.
- **Linux.** `PageRangeStore` imports SQLite3 behind `canImport`, else `CSQLite`. It binds text with `SQLITE_TRANSIENT` where it bound a temporary `NSString`'s buffer as static, which only Apple's autorelease pool kept alive.
- **Tests.** Three suites dual-compiled, and `CitationTestSupport.swift`. It reads the bundled manifest from the repository in the package, and builds a `FixedVolumeCatalogue` where Xcode builds a `ManifestStore`.
  - Three guards are lifted: `CitationLookupFieldsTests`, the manifest-backed punctuation test, and `matchSurvivesNoisyVolume`.
  - A new suite, `CitableVolumeCatalogueTests`.
  - `FRUSCoreKitTests` goes from 765 tests in 108 suites to 878 in 116.
- **Audits and docs.**
  - The boundary audit is unchanged.
  - Four path reads, and one count-scan baseline key.
  - The app's `CLAUDE.md`.
  - 16 editable-content paths and 12 ranges.
  - Version histories.
  - The session entry.

**Results at the pull request's head**

- **Check 7's matcher half on Linux.** Check 7's three parts, in the same setup as S6a (a scratch checkout of this repository, the branch copied into its submodule folder, `Package.swift` patched as the pin move will patch it):
  - CitationMatchingEngineTests' 70: 27 in its first suite and 43 in `CitationLookupIndexedTests`;
  - CitationBlockSplitterTests' 18;
  - the punctuation test, which reads the bundled manifest.

  All pass, inside "✔ Test run with 878 tests in 116 suites passed", none skipped, in 24 s. With S3's formatter and parser half, 81 tests, check 7 runs 170 tests on Linux.
- **The matcher on both platforms.** In Debug, the engine's suites print 3,732 log lines: each lookup's strategy and verdict, and the round trip of the app's own citation of all 553 bundled volumes in three formats, marked and plain. In each of the six forms, 551 of 553 resolve first to their own volume. The lines are identical on macOS and on Linux.
- **The whole Linux suite** passes, except the three tests that check the golden files' provenance. Those fail only on the source digest, as they must until the pin move remakes the golden files, and their row comparisons pass.
- **Checks 2 and 3, unchanged.** The S6a probe, rerun at this head:
  - check 2: "check 2 passes: 36 digests and 7 checks";
  - check 3: "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups".

  Xcode was building at the same time, so this run's timings are not measurements.
- **Check 4 at the head.** `tools/mac-golden`, built against the branch, wrote all 392 rows' HTML and all 482 queries' expressions byte-identical to the committed golden files. Only their provenance changed.
- **macOS and iOS**, which the upstream description gives in full:
  - **Builds and symbols.**
    - Clean unsigned builds of `FRUSExplorerMac` succeed beside `v2`'s, with the same five warning lines.
    - The normalized symbol diff is 29 removed and 59 added, each name explained.
  - **The full unit run:** "✘ Test run with 6498 tests in 765 suites failed after 479.912 seconds with 8 issues."
    - The 8 are the Keychain tests that an unsigned build fails.
    - The 4 extra tests are the new suite's.
    - The run skips the same 17 tests and 2 suites as `v2`.
  - **`swift test`, whole:** 38 runs and 2,541 tests, all passed.
  - **The audit, mutated:** four of its twelve tests failed on four planted violations, each naming its line.

**Delivered here**

- **`PLAN.md`** and its shared copy (rev 78):
  - the S6 row's check 7 count, 70 of 74;
  - Mac check 3: A done, B awaiting the owner.
- **`docs/COORDINATION.md`** section 2: A merged; B open, with the catalogue seam and how the server will pass the manifest. Section 3: the imports the audit allows since #1573.
- **`docs/prep/README.md`:** what B settled.

**Results here**

No code changed. CI runs the suite at `af8bedab` as before, 1,136 tests.

**The pin-move pull request, after #1574 merges**

As S6a listed, and also:
- **Check 7 in CI.** `FRUSCoreKitTests` at the new pin includes check 7's matcher half, 89 tests, with no change to this repository beyond the pin and `Package.swift`.
- **CI's skip check** (`.github/workflows/ci.yml`, the Test step) matches any log line with `Test`, then `skipped` after a space. At the new pin, one passing test's name contains the word: "A Lot File(s) prefix is skipped, never captured into the key". The pattern needs to require the verb right after the test's name, keeping XCTest's `Test Case '…' skipped` form. The scratch checkout's full Linux log has no other such name.
- **`docs/SPEC.md` and `PLAN.md`** name no moved citation file by path, so nothing else moves.

**Next.**
- The owner: Mac check 3 on #1574, with the commands in its description, and then the merge.
- Then the pin move after both, with a new three-volume export from the newly pinned build.
- A web session adds the daily watch of the app's `v2`, as section 5 of `docs/COORDINATION.md` describes.

## Session 6a: FRUSCoreKit, part 2, upstream pull request A

4–5 October 2026 · branch `claude/s6-fruscorekit-part2` · upstream [joshbotts/FRUS-Explorer#1573](https://github.com/joshbotts/FRUS-Explorer/pull/1573)

S6's first upstream pull request moves the app's indexing pipeline and search service into `FRUSCoreKit/`, so that this repository can index and search on Linux with the app's own code. It branches from `v2` at `af8bedab`, which is still the pin; nothing has merged on `v2` since. As with S3, this entry records the results at the pull request's head. The indexer and search reach this repository's CI in the pin move that follows both of S6's pull requests. This pull request makes the parity tools ready for that, and passes CI at `af8bedab`.

**The owner's decisions, 4 October**

- **Two upstream pull requests and one pin move.** A moves the indexer and search, which brings checks 2 and 3 to Linux. B, branched from `v2` after A merges, moves the citation matcher, the block splitter and `PageRangeStore`, which brings check 7's matcher half. One pin move follows both, so the owner makes one new three-volume export.
- **All of `IndexingPipeline.swift`, and the core suites.** A moves the whole file and the Foundation-only types it uses, and about 370 of the indexer's and search's tests compile twice, under Xcode and against the kit alone.
- **No `UserDefaults` or `Bundle.main` in the kit.** The stamps go through a stamp-store interface that `UserDefaults` already satisfies. The data files go through providers the app passes, so nothing loads earlier than before. The boundary audit lets the kit import logging, SQLite (`CSQLite` on Linux) and FTS5Store, each behind the `canImport` that selects it.
- **Mac check 3 takes Mac check 2's form,** once for each pull request.
- **Left to the session, as recommended:**
  - one kit call runs the passes after indexing, and the app's launch calls it too;
  - the iOS memory-warning observer stays where it is, matched by the notification's name;
  - only what S6's checks need becomes public;
  - indexing is measured on the fixtures and on a sample of 20 to 30 volumes;
  - check 3 keeps to exact ties.

**How the session got there**

- **A map first.** Six readers mapped the code's dependencies at `af8bedab`: the indexer, search, the citation matcher, the stores, the tests and this repository's side. A seventh synthesized the plan and the decisions above. `docs/prep/s6-linux-edits.tsv`, from the dry run at `34a5120`, was a list of guards. The map showed that moves avoid most of them:
  - the pipeline needs kit internals, so it lives in `FRUSCoreKit` itself;
  - six data files are read, not eight;
  - the Keychain and NARA shims are unneeded.
- **Two audits before the pull request opened.**
  - **The tree walks.** A scan of the test target's 50 walks of `FRUSExplorer/` judged whether each could stop reading code that moved, and each change it proposed was checked again independently: nine path reads, four walks widened to `FRUSCoreKit/`, and one repository path in a moved suite.
  - **The whole change.** Five reviewers looked at behaviour preservation, the seams, the tests, the records and this repository's tools, and each finding was checked by a skeptic. 20 of the 28 findings held, some found twice, and all were fixed before the pull request opened. Among them:
    - `runPostIndexPasses` held the pipeline's actor across all three passes where the launch had released it between them; it is `nonisolated` now;
    - one sanity set no longer proved that the walk reads the test target's free functions;
    - several guard reasons, counts, commit-message details and doc sentences were wrong.
  - **And one the session found itself.** The pipeline's comment said a test pinned the memory-warning notification's name, and none did. `IndexingSeamsTests` now does, and also checks that `IndexingResources.bundled` serves the app's stores and tests the seams under both compilers.

**The upstream pull request**

Branch `claude/fruscorekit-part2`: ten commits in review order. Its description lists them and holds the Mac check 3 commands, the expected results and the symbol-diff script.

- **Moves.** Fourteen files by `git mv`:
  - `IndexingPipeline`, `SearchService`, `KWICLine`, `PersonClusterer`, `ResultSetFacets`, `DecimalFileSegment` and `IndexingStateTracker`;
  - `ChronologyModels`, `DocumentKey`, `PersonMentionStore`, `PersonAuthorityIndex` and `VolumeSubjectProfiles`;
  - two renamed: `DocumentSubjectIndex` and `DecimalClassLabelTable`.

  Fourteen Foundation-only value types moved verbatim into six new kit files, `SearchParameters.swift` among them. The kit goes from 10,183 lines in 18 files to 29,219 in 40.
- **The seams** (`FRUSCoreKit/Search/IndexingSeams.swift`):
  - `IndexingResources`, with `.none` and `loading(fromDirectory:)`, which refuses a folder lacking one of the four files that change an index;
  - `IndexingStampStore`, whose requirements are `UserDefaults`' own methods, and `InMemoryIndexingStampStore`;
  - `IndexedDocumentDonor` and `DonatedDocument`;
  - `runPostIndexPasses(overrides:afterRollupRebuild:)`.
- **The app's half** (`IndexingPipeline+App.swift`): the old initialiser, passing `.bundled`, `UserDefaults` and the Spotlight donor; the Spotlight section; `updateSummary(_:)`. The app's three launch branches call `runPostIndexPasses`.
- **Linux.** Guarded imports, and the kit's own copy of FTS5Store's logging stand-in. The kit depends on FTS5Store.
- **Tests.** Thirteen suites dual-compiled, and `IndexingTestSupport.swift`, which gives the package's pipelines the app's data files and one shared stamp store. `FRUSCoreKitTests` goes from 393 tests to 765.
- **Audits and docs.**
  - `FRUSCoreKitBoundaryTests` 1.2.
  - Nine path reads, and four tree walks widened to `FRUSCoreKit/`.
  - The app's `CLAUDE.md`.
  - 35 editable-content ranges, the API spec and version histories.
  - The session entry.

**Results at the pull request's head**

- **Linux, `swift:6.4-noble`, arm64.** The setup: a scratch checkout of this repository, with the branch copied into its submodule folder and `Package.swift` patched as the pin move will patch it (FTS5Store and `CSQLite` for the kit and its tests).
  - `FRUSCoreKit` builds with no warning.
  - "✔ Test run with 765 tests in 108 suites passed", none skipped. The other kit targets pass.
  - This repository's own harness fails only where it must until the pin move. The golden files' provenance names `af8bedab`'s sources. `CompatibilityTests` on `main` reads `IndexingPipeline.swift` at its old path, which this pull request's path tolerance fixes.
- **Checks 2 and 3 on Linux.** A throwaway probe in the scratch checkout, not committed, used the kit's public API alone, as the server will:
  1. `FTS5Store` and `IndexingPipeline(resources: .loading(fromDirectory:), defaults: InMemoryIndexingStampStore())`, with the submodule's `FRUSExplorer/Resources`;
  2. `indexVolume` for the three fixtures;
  3. `runPostIndexPasses()`;
  4. a page-for-page copy in rollback-journal mode through SQLite's backup API, then `IndexSummarizer`;
  5. `SearchService`, with `tools/mac-golden`'s results loop.

  The results:
  - **Check 2:** "check 2 passes: 36 digests and 7 checks", against the golden summary of the owner's three-volume export. So a raw Linux index, copied without the app's exporter, equals the Mac's export.
  - **Check 3:** `frus-parity compare-results` printed "check 3's results pass: 482 queries, 482 identical and 0 reordered only within Mac tie groups".
    - 359 passing queries have other score bits than the Mac's: 1,349 scores in all, each 1 to 3 ulp away (1,165 one, 182 two, 2 three), the largest relative difference 4.3 × 10⁻¹⁶.
    - The smallest gap between two distinct adjacent Mac scores is 4.6 × 10⁻⁸. So rounding cannot reorder results, and exact ties stay the right rule.
  - **Speed and memory,** release, an idle Mac with 10 CPUs:
    - the three volumes index in 0.53, 0.28 and 0.30 s;
    - the passes after indexing take 0.05 s, so 1.18 s in all;
    - the 482 queries take 10.7 s, counting the paging of tie tails;
    - the peak resident memory is 130 MiB (VmHWM 133,228 KiB).
- **Check 4 at the head.** `tools/mac-golden`, built against the branch in the scratch checkout, wrote the HTML of all 392 rows and the expressions of all 482 queries byte-identical to the committed golden files. Only their provenance changed. The Linux renders against those files: "check 4, the reader's path: 392 of 392 rows identical", and so along the full-parse path.
- **macOS and iOS**, which the upstream description gives in full:
  - Clean unsigned builds of `FRUSExplorerMac` succeed beside `v2`'s, with the same five warning lines.
  - The normalized symbol diff is 97 removed and 389 added, each name explained.
  - A clean iOS `build-for-testing` takes 144 s, with the 7 known warning lines.
  - **The full unit run:** "✘ Test run with 6494 tests in 764 suites failed after 373.887 seconds with 8 issues." `v2`: "✘ Test run with 6486 tests in 763 suites failed after 389.226 seconds with 9 issues."
    - Both fail the 8 Keychain tests an unsigned build fails; `v2` also had the late-image flake.
    - Both skip the same 17 tests and 2 suites.
    - The 8 extra tests are the new seams suite's.
  - **`swift test`, whole:** 38 runs and 2,428 tests, all passed.
  - **The audit, mutated:** five of its twelve tests failed on seven planted violations, each naming its lines.

**Delivered here**

- **Check 3's results comparison.**
  - `Tests/FRUSParity/SearchParity.swift` compares a candidate results file with `fixtures/golden/queries.results.json`. It uses ParityFormat's tie-aware `ResultComparison` for each query and reports four things:
    - each permutation inside a Mac tie group;
    - each difference: a count, a missing or extra document, an order outside a tie, an error string, or a missing, extra or repeated record;
    - which passing queries have other score bits, as information.
  - `frus-parity compare-results <golden> <candidate>` prints "check 3's results pass" or "fail": the compiled expressions are the rest of check 3, and ParseParity's.
- **`Tests/FRUSParity/IndexingMetrics.swift`:** step timing with `ContinuousClock`, documents per second, and the process's peak resident memory (VmHWM on Linux, `ru_maxrss` on macOS), for the pin move's indexing measurements.
- **Path tolerance for the move.** `CompatibilityTests` and `scripts/mac-check` read the index version from whichever of `FRUSExplorer/Search/` and `FRUSCoreKit/Search/` holds `IndexingPipeline.swift`, and fail if both or neither do.
- **Tests:** 14 new in FRUSParityTests (11 for the comparison, among them the committed results file against itself, and 3 for the metrics), so 76.
- **The docs.**
  - `PLAN.md` and its shared copy (rev 75): the S6 row (two pull requests, one pin move), Mac check 3, the owner's decisions, and two risk rows.
  - `docs/COORDINATION.md` section 2: part 2's two pull requests, A's seams, and the guarded imports the audit will allow.
  - `docs/prep/README.md`: what A settled, and what remains of `s6-linux-edits.tsv` and `shims/`.

**Results here**

- **Linux, `swift:6.4-noble`, arm64.** All 1,136 tests pass, with the one named skip:

  | Target | Tests |
  | --- | --- |
  | FRUSCoreKitTests | 393 |
  | SourceNoteKitTests | 292 |
  | FTS5StoreTests | 209 |
  | FRUSParityTests | 76 |
  | ManifestGeneratorTests | 60 |
  | FRUSLightCoreTests | 42 |
  | SemanticVectorsKitTests | 35 |
  | CrossRefKitTests | 10 |
  | FRUSLightServerTests | 9 |
  | GeneratorKitTests | 7 |
  | FTS5CheckTests | 3 |

- `frus-parity compare-results` passes the committed results file against itself, and the probe's Linux results from the head as above.

**The pin-move pull request, after both merges**

- **`Package.swift`.** `FRUSCoreKit` gains FTS5Store and `CSQLite` on Linux; `FRUSCoreKitTests` gains FTS5Store, SourceNoteKit and `CSQLite`, as the scratch package had them.
- **The indexer and search in CI,** with the probe's steps as tests. They index the fixtures once per process with `IndexingResources.loading(fromDirectory:)` over the submodule's resources and an in-memory stamp store, then run the passes:
  - check 2: copy the index with the backup API into rollback-journal mode, summarize it and compare;
  - check 3: run the 482 queries with `tools/mac-golden`'s loop and compare with SearchParity;
  - a test that the four index files are present and decode;
  - `frus-parity index --metrics`.

  Check 3's expressions for the queries outside the default scope still need a Linux comparison.
- **Golden files.** All four, remade by `scripts/make-golden --export` from a new three-volume export by the newly pinned build. The source digest changes with the move.
- **Paths.** `docs/SPEC.md` and the comments citing `IndexingPipeline.swift` by line move with it.

**Notes**

- **For S8.** The pipeline's initialiser opens its database read-write, runs its schema setup and sets WAL mode, which does not suit an immutable export. S8's own upstream pull request needs a read-only open, with the figure URLs and the page shell it already needs.
- **On Linux,** `IndexingResources.loading(fromDirectory:)` answers nothing for the collection authority's alias fallback, which only related-documents queries use. It changes no index.
- **The probe and the scratch checkout** are not committed. The pin move's tests replace the probe.
- **The owner's next steps:** Mac check 3 on #1573, from a clone at a real path, with the commands in its description, and then the merge.

**Next.**
- S6b: the second upstream pull request, the citation matcher, the block splitter and `PageRangeStore`, with check 7's matcher half, branched from `v2` after #1573 merges.
- Then the pin move after both, with a new three-volume export from the owner.
- A web session adds the daily watch of the app's `v2`, as section 5 of `docs/COORDINATION.md` describes.

## Golden files from the owner's three-volume export

4 October 2026 · branch `claude/golden-export`

The owner built FRUS Explorer from `af8bedab`, the pin, as build 49. Their Apple ID held no FRUS Explorer data, so instead of setting up a second macOS user they emptied the app's own 553-volume library with Settings ▸ Data & Recovery ▸ Erase Everything…. They then downloaded the three fixture volumes, let indexing and the person rollup finish, and exported the research database with Include My Notes, Summaries, and Tags turned off, to `/Users/Shared/frus-golden.sqlite`. This pull request commits the two golden files made from that export, which completes the Golden files checkpoint. The server, the image and `compose.yaml` are unchanged.

**Delivered**

- **`fixtures/golden/index-summary.json`,** check 2's golden summary, 32,682 bytes: 36 gating digests and 7 checks over exactly the three fixture volumes.
  - Among its tables: 392 `document_cache` rows, 121 persons, 1,018 person mentions, 1,130 page ranges, 208 cross-references, 98 terms, 1,242 document subjects and 9 external citations.
  - Every check has its right value: `integrity` ok, no `docsize` orphans in either full-text table, no revision history, `user_version` 4.
- **`fixtures/golden/queries.results.json`,** check 3's counts and first 50 results, 844,004 bytes, one record for each of the 482 queries:
  - 439 have a count, and 178 exceed 50. 27 are zero, each by design. For 22 of them, the query's note in `fixtures/parity/queries.jsonl` says so. The other five are R55's queries, which search with document text off over an index that holds no notes or summaries, as `fixtures/parity/README.md` says.
  - 12 have one result after the 50th that ties with it, kept in the record's tie tail.
  - 43 are refused as `emptyQuery`: the same 43 the expressions file refuses.
- **`fixtures/golden/PENDING`** lists nothing, so `GoldenTests` validates all four golden files and none waits.
- **The other two golden files** were made again at `af8bedab` in the same run, byte-identical to the committed ones.
- **`scripts/make-golden`'s header** names the route the owner took, and says why Reset This Device does not do (see the notes).
- **The docs.**
  - In `PLAN.md` and its shared copy (rev 74), the Golden files checkpoint is Done. The Mac item for a pin move now asks for a new three-volume export and `scripts/make-golden --export`.
  - `docs/COORDINATION.md` says the export-based golden files exist, and that a pin move remakes them from a new export, in sections 1, 2, 5 and 6.
  - `docs/prep/README.md`'s pinning note says each pin move remakes them from a new export.

**Results**

- **The export.** Index version 65, FTS schema 4, `user_version` 4, app build 49, `my_writing_included` 0. It holds the three fixture volumes alone: 392 `document_cache` rows, and 392 `document_revisions` rows, all at index version 65. The app's three downloads match `fixtures/tei/SHA256SUMS`, and HistoryAtState's `master` is still `8e5da08`.
- **`scripts/make-golden --export`** on the owner's Mac, macOS 27.0.1 with Xcode 27.0: every step ok. "results: 482 queries, 43 refused, 12 with ties past the 50th", and `frus-parity check-golden` passes.
- **A cross-check against a new index.** Emptying a library that had held 553 volumes might leave something behind. To test that, a throwaway `mac-golden` command, not committed, built a new `frus.db` from the three fixtures with the app's own code:
  1. `FTS5Store` and `IndexingPipeline`, constructed as `mac-golden results` constructs them, with the app's 36 JSON resources beside the tool;
  2. `indexVolume` for each fixture;
  3. `consolidatePersonRollupIfNeeded` with no overrides, then `applyBrokenRefsIndexIfNeeded` and `applyDocumentSubjectsIfNeeded`, the passes the app runs after indexing;
  4. `IndexDatabaseExporter.export`, with the writing left out, as Export Research Database… does, but with a stamp the command built itself.

  `frus-parity compare-summary` of the golden summary against it: "check 2 passes: 36 digests and 7 checks are identical". `mac-golden results` over it gave all 482 records identical to the golden file. So the golden files describe the index a new library makes. The two summaries differ only in information they do not compare. Besides the export time and the timings, the differences are:
  - `sqlite_sequence`. The emptied library's counters continue from the 553-volume library's: `page_ranges` is at 766,807 against 1,130. The summary leaves those surrogate ids out of every hash. They also account for the file sizes and page counts: 5,111,808 bytes in 1,248 pages, against 5,099,520 in 1,245.
  - `volume_structures.json`. Each process encodes the structure JSON with its keys in another order; the two are equal as JSON.
  - The stamp's `semantic_provenance_digest`. The app stamps its bundled vectors' digest, `a726ca60…`. The throwaway command loaded no vectors, so its stamp has none.
- **The same index without the resources.** With no JSON resources beside the tool, check 2 fails with 15 gating differences, in five tables. `document_subjects`, `document_subject_refs` and `document_subject_volumes` are empty, `external_citations` has 4 rows instead of 9, and the `person_rollup` content differs. So the check catches an index made without them.
- **Linux, `swift:6.4-noble`, arm64.** All 1,122 tests pass, with the one named skip, in 1 minute 50 seconds with an incremental build. `committedGoldenFilesAreCurrentAndWhole` finds nothing pending, and `frus-parity check-golden` prints "golden files: 4 present and valid, 0 pending".
- **macOS, natively.** FRUSParityTests' 62 tests pass, both renders giving 392 of 392.

**Notes**

- **Erase Everything, not Reset This Device.** Both delete the volumes, their figures and the search index. Reset This Device keeps `document_revisions`, the per-document change log, since it promises that annotations come back; only Erase Everything clears it. After Reset This Device, an export would still name every volume the library held in that table, and `frus-parity summarize` refuses an export whose tables name volumes `document_cache` does not hold. Erase Everything also deletes every note, collection and project, on the device and in iCloud, so it suits only an account with nothing to keep, as the owner's was.
- **The owner's library now holds the three fixtures alone.** `~/Documents/frus-index.sqlite`, the 553-volume export of 3 October from build 49, is unchanged. It stays the input for local Import trials while the pin holds. The S10 export needs a full library again, from the build pinned at S10.
- **For S6.** The cross-check shows the app's own code making, from scratch, the index the golden summary describes. It needs the indexing calls and the three passes above, and the bundle's JSON resources. A Linux index made the same way should pass check 2; one made without the resources fails it in those five tables. S6's upstream pull request only moves code, so in the session its Linux index can be compared with these files by `frus-parity compare-summary`, which compares no provenance. Its pin move changes the source digest, so that pull request remakes all four golden files, the two from an export with a new three-volume export from the newly pinned build.
- **The platform recorded** in both files: macOS 27.0.1, SQLite 3.54.0, `en_US`, America/New_York. Check 2 compares no platform field.

**Next.**
- S6: FRUSCoreKit part 2, an upstream pull request that moves the indexer, search, the citation matcher and splitter, and `PageRangeStore` into the kit. Its pin move remakes the golden files from a new three-volume export, as the note above says, and runs checks 2 and 3 on Linux against them, with check 7's matcher and splitter half.
- A web session adds the daily watch of the app's `v2`, as section 5 of `docs/COORDINATION.md` describes.

## Pin move: FRUSCoreKit on Linux in CI

4 October 2026 · branch `claude/pin-2a4df13` · upstream [joshbotts/FRUS-Explorer#1569](https://github.com/joshbotts/FRUS-Explorer/pull/1569), merged as `f102fa4d`, [#1571](https://github.com/joshbotts/FRUS-Explorer/pull/1571), merged as `2a4df13c`, and [#1572](https://github.com/joshbotts/FRUS-Explorer/pull/1572), merged as `af8bedab`

The owner ran Mac check 2 and squash-merged #1569 as `f102fa4d`, then #1571, which narrows the boundary test, as `2a4df13c`, and #1572, the app's `CLAUDE.md` section for the web edition, as `af8bedab`. They are the only commits on `v2` after `cfc0d3c`. This is the pull request Session 3's entry describes: it moves the pin, compiles FRUSCoreKit and its suites, and runs check 4 on Linux in CI. The index version stays 65, the FTS schema 4 and the app build 49, so `Compatibility.swift`, `docs/INSTALL.md` and the export's schema fixture are unchanged.

**Delivered**

- **The pin** moves from `cfc0d3c` to `af8bedab` (rule 5). #1572, the last of the three, changes only `CLAUDE.md` and the app's session log, which no golden file digests. The submodule has no local changes.
- **`Package.swift`,** with the targets of the working manifest in #1569's description:
  - `FRUSCoreKit`, from the submodule's `FRUSCoreKit/`. It depends on SourceNoteKit, as upstream's manifest declares, and on swift-crypto's `Crypto` for Linux only, which its `CryptoKit` guard falls back to.
  - `FRUSCoreKitTests`, the kit's eleven suites from `FRUSExplorerTests/FRUSCoreKit/`, depending on the kit alone: under SwiftPM each suite imports FRUSCoreKit and nothing else.
  - FRUSParity depends on the kit, for check 4. FRUSLightCore and the server depend on neither target, and `Package.resolved` is unchanged.
- **Check 4 on Linux.** `Tests/FRUSParity/RenderParity.swift` renders the fixtures through the kit's public API alone. It imports the kit without `@testable`, as the server will. `RenderParityTests`, in FRUSParityTests, has four tests:
  - **The reader's path,** for each of the 392 rows of `fixtures/golden/render/manifest.json`:
    1. a new parser's `parseDocument`;
    2. `ReaderLookups` from the volume's `parsePersons` and `parseTerms`;
    3. `ASTToRenderNodeConverter(readerOf:lookups:brokenRefs:)`, with the submodule's `FRUSExplorer/Resources/broken-refs-index.json` decoded as `BrokenRefsIndex`;
    4. `FRUSRenderNodeHTMLSerializer.reader`.

    Each row's UTF-8 bytes must be the committed file's, and their size and SHA-256 the manifest row's. A difference reports both, and `RenderDiff.firstDifference`.
  - **One full parse per volume,** the path S8 will serve, without a parse per document. `parseVolumeFull` must yield exactly the golden rows, in their order. Rendering from its ASTs, with its own persons and terms, must give the same bytes. Its persons and terms must also equal `parsePersons` and `parseTerms`, field for field, since the bytes cannot show them (see the notes).
  - **An `<abbr>` naming a glossary term,** in a volume the test writes. Along both paths it renders as the term's link whatever its case, and an `<abbr>` that names no term stays text.
  - **The comparison itself,** on golden files the test writes. Identical HTML passes. Canonically equivalent text, a missing document, an unlisted row and a manifest that disagrees with its file are each reported.

  Both renders first require the golden manifest to be current at the pin, by `GoldenValidation`'s staleness check. One made from other app sources would test other code, so it fails as stale instead.
  - The persons and terms are parsed once per volume. The reader parses them for each document it opens, but `FRUSDocumentParser` keeps no state between calls: each reads the file with a new `XMLParser`.
  - Rows render concurrently, as many at once as the machine has processors.
- **`frus-parity render`** runs check 4 on any machine, both passes, and prints their timings. It also compares the full parse's persons and terms with the reader's. Given a volume and a document, it renders that one, along the reader's path or with `--full-parse`, and `--out` saves its HTML. The HTML never goes to standard output, where a debug build of the kit prints its parser's log.
- **Check 7's formatter and parser half** runs in CI, inside FRUSCoreKitTests: 81 tests in all.
  - The eight suites `CitationFormatterTests.swift` compiles under `swift test`: 32 tests.
  - CitationParserTests: 26.
  - The three suites in `PageSpanResolverTests.swift`: 23.
- **Golden files.** `scripts/make-golden` ran on the owner's Mac at `2a4df13`, and again at `af8bedab`, where only the recorded commit changed, in 89 seconds.
  - `tools/mac-golden` compiled 529 app files and the stub, all 18 of FRUSCoreKit's among them.
  - The HTML of all 392 rows (3,554,115 bytes) and the expressions of all 482 queries are byte-identical to `cfc0d3c`'s.
  - Only the provenance changed, in four lines: `upstreamCommit` and `sourceDigest`, in `render/manifest.json` and `queries.expressions.json`. `check-golden` passes.
  - The new digest, `39d9aed1…`, is the one S3 rehearsed at #1569's head. A Python recomputation gives the same over 612 files. Without `FRUSCoreKit`, the other 594 files give `b425aaa1…`.
- **CI needs no change.** The kit's suites skip nothing on Linux, none calls `Test.cancel`, and no line of their log matches the skip guard's pattern.

**Results**

- **Linux, `swift:6.4-noble`, arm64.** A clean build with tests: "Build complete! (59.52 secs)", 86 seconds with the dependencies' checkout, and no warnings. Of the 1,122 tests, 1,121 pass, and the one skip is the named one:

  | Target | Tests |
  | --- | --- |
  | FRUSCoreKitTests | 393 |
  | SourceNoteKitTests | 292 |
  | FTS5StoreTests | 209 |
  | ManifestGeneratorTests | 60 |
  | SemanticVectorsKitTests | 35 |
  | CrossRefKitTests | 10 |
  | GeneratorKitTests | 7 |
  | FRUSParityTests | 62 |
  | FRUSLightCoreTests | 42 |
  | FRUSLightServerTests | 9 |
  | FTS5CheckTests | 3 |

  - The seven kits hold 1,006 of them: S1's 613, and FRUSCoreKitTests' "✔ Test run with 393 tests in 49 suites passed after 0.100 seconds.", the count #1569 states.
  - FRUSParityTests has four tests more than before. The renders print "check 4, the reader's path: 392 of 392 rows identical" and "check 4, one full parse per volume: 392 of 392 rows identical, and its persons and terms are the reader's: 0 and 0, 58 and 19, 63 and 79".
- **macOS, natively.** The same 1,122 tests, with the same counts per target, all pass with none skipped. A clean build: "Build complete! (46.40 sec)", with no warnings. FRUSCoreKitTests: "✔ Test run with 393 tests in 49 suites passed after 0.066 seconds." Both renders give 392 of 392.
- **The guard.** The Test step's script and No runtime skips, read from `ci.yml`, ran in the swift image under `bash -eo pipefail`, with `LANG` unset and set to `C.UTF-8`, against this branch's real Linux log.
  - Both pass, and the named skip appears once.
  - No runtime skips searched 27 directories, the kit's two among them. It fails when `Test.cancel` is planted in a kit suite.
- **A difference, planted.** One character added to a golden file made both renders fail on that row alone. Each named the row and printed the first differing piece, ending "February 13, 1961.X</p></div>" in the golden file and "February 13, 1961.</p></div>" in the render.
- **The lookups, broken on purpose.** Rendering with empty lookups, along either path, fails the `<abbr>` test for that path while the 392 rows still match. A full parse that loses its last person, or one volume's terms, fails the list comparison.
- **Timing.** Testing took 113 seconds on Linux arm64 with 10 CPUs, 98 of them in FTS5StoreTests.
  - The test targets run one after another, so FRUSParityTests' time adds to the step's: 7.4 seconds, up from 3.9 at `cfc0d3c`.
  - Within that run, the reader's path took 7.1 seconds and the full-parse pass 3.2. Run alone, they took 4.0 and 0.6, and with Docker limited to 4 CPUs the reader's path took 7.5.
  - At PR #15, GitHub's amd64 runner ran FTS5StoreTests 3.9 times slower than this Mac (372 seconds against 96). At that ratio, the reader's path should take about 30 seconds there, and FRUSCoreKitTests well under one.
  - macOS took 87 seconds to test.
- **The image is unaffected.** `scripts/compose-smoke` passes. The image's build compiled FRUSLightCore and the server and no kit, and the stripped server binary was byte-identical to the previous build's: its layer came from the cache. The image is still 251 MB.

**Notes**

- **The parser's debug log.** A debug build of the kit prints `[TEIParser]` lines, so the Linux test log now holds about 1,000 of them, about 580 from the renders. Most are "Warning: unparseable <pb n=…>", for two bracketed page numbers that every parse of their volume meets. They match neither guard pattern.
- **The golden HTML cannot show the lookups.** The serializer writes a person's or a term's link from its ref alone, and drops the entry the lookup found. The one link a lookup decides, an `<abbr>` whose text names a term, occurs in none of the three fixture volumes. So the 392 rows would match with empty lists, or another volume's, as review showed by rendering with empty lookups. The full-parse test therefore compares the lists themselves, and the `<abbr>` test covers the one lookup that changes the HTML.
- **For S8.** `parseVolumeFull`'s persons and terms are `parsePersons`' and `parseTerms`', field for field, in all three volumes (none in the 1894 volume, 58 persons and 19 terms, and 63 and 79). Rendering from its ASTs gives the same bytes. So one XML pass per volume gives the server everything the reader's HTML needs.
- **The owner's next Mac build comes from `af8bedab`,** for the Golden files checkpoint, as `PLAN.md` says for a pin move. The S10 export will come from the build pinned at S10, after S6's pin move.
- **Mac check 2 is Done** in `PLAN.md`'s owner checkpoints. `docs/COORDINATION.md` records that FRUSCoreKit is compiled, that the CI compares both golden files made from the app's source, and that #1571 has merged.

**The owner's next step.** The three-volume export for the Golden files checkpoint can now be made, from a Mac build of `af8bedab`, in a library holding exactly the three fixture volumes. `scripts/make-golden --export <file>` then writes `index-summary.json` and `queries.results.json`. The top of the script says how to make the export.

**Next.**
- After the export, S6: FRUSCoreKit part 2, the indexer and search on Linux, and check 7's matcher and splitter half.
- Done alongside: #1572 added `docs/COORDINATION.md`'s appendix block to the app's `CLAUDE.md`, closing [joshbotts/FRUS-Explorer#1570](https://github.com/joshbotts/FRUS-Explorer/issues/1570).
- A web session adds the daily watch of the app's `v2`, as section 5 of `docs/COORDINATION.md` describes.

## Coordination with the app's repository

4 October 2026 · branch `claude/coordination`

**Delivered:** `docs/COORDINATION.md`, a proposal the owner asked for, for Claude Code sessions in both repositories. The owner directed that synchronization work, and its token cost, fall on this repository's sessions. The app's sessions are not to be diverted beyond a few agreed rules, and app changes only the web edition needs are this repository's to write. The document:
- explains how the web edition uses the app's code: the pin, the shared kits, the index and export contract, and the golden files;
- explains how #1567 and #1569 made that code portable, and what part 2 will move;
- describes the app architecture that protects the arrangement: kit folders compiled twice, the FRUSCoreKit boundary test, forwarders, and single entry points;
- sets four rules for app sessions, and lists what they are not asked to do;
- assigns the rest to web sessions: a daily Linux watch of the app's `v2` (to be built), repairs, every web-only app change, pin moves and conflicts;
- includes a block for the app's `CLAUDE.md`.

It is filed for the app's sessions as [joshbotts/FRUS-Explorer#1570](https://github.com/joshbotts/FRUS-Explorer/issues/1570), which closes when the `CLAUDE.md` pull request merges. Three review rounds checked it against both repositories, and fixed several overstatements. Two of them needed fixes upstream. #1569 had merged by then, so they went in a follow-up, [joshbotts/FRUS-Explorer#1571](https://github.com/joshbotts/FRUS-Explorer/pull/1571):
- `public` does not mark web use, because most kit declarations were already public;
- the boundary test could trip on an app-only change, so its name check was narrowed.

**Next.** #1569 has merged. A web session:
- moves the pin to it (S3's pin move);
- opens the pull request adding the `CLAUDE.md` block to the app's repository;
- adds the daily watch.

## Session 3: FRUSCoreKit, part 1, upstream

4 October 2026 · branch `claude/s3-fruscorekit` · upstream [joshbotts/FRUS-Explorer#1569](https://github.com/joshbotts/FRUS-Explorer/pull/1569)

S3's upstream pull request, the second, moves the TEI pipeline and the citation code out of `FRUSExplorer/` into `FRUSCoreKit/`, a Foundation-only directory that both app targets compile and upstream's `Package.swift` builds as a target of its own. It branches from `v2` at `cfc0d3c`, which is still the pin; nothing has merged on `v2` since. As with S1, this entry records the results at the pull request's head, and the kit reaches CI in the pin-move pull request after the owner's Mac check 2 and merge. This pull request makes the parity tools ready for that pin, and passes CI at `cfc0d3c`, where `FRUSCoreKit` does not exist yet.

**The owner's decisions, 4 October**

- **Land it now,** while `v2` is quiet, rather than after the public release.
- **All of part 1:**
  - the TEI pipeline;
  - the citation formatter, parser and models, and `PageSpanResolver`;
  - the reader's path as the kit's API, which `DocumentViewModel.load` and `HTMLTemplate.build` call: `ReaderLookups`, `ASTToRenderNodeConverter.init(readerOf:lookups:brokenRefs:)` and `FRUSRenderNodeHTMLSerializer.reader`;
  - public access for the types S8 and S9 will need, provided each is what they need and making it public changes nothing for the app.

  The citation matcher, the block splitter and `PageRangeStore` stay in the app for S6, which brings the SearchService and ManifestStore they need.
- **The kit's suites are compiled twice,** by Xcode and by `swift test`, in `FRUSExplorerTests/FRUSCoreKit/`. Whatever needs the app sits behind `#if !SWIFT_PACKAGE`. Three more parser suites join them. A source audit guards the kit's boundary, and the tree-walking audits read `FRUSCoreKit/` wherever their rules apply.
- **Mac check 2:**
  - clean builds of both schemes;
  - the full iOS unit run, signed, with `v2`'s skips;
  - `swift test`, with the `FRUSCoreKitTests` count the pull request states;
  - a normalized symbol diff that shows only the names the pull request expects.
- **The three-volume export waits.** The owner's export for the Golden files checkpoint comes after the S3 pin move. That move changes the source digest, so golden files made from an export at `cfc0d3c` would go stale with it.
- **Left to the session:**
  - the trial's names: `FRUSURLScheme`, `HighlightColor`, `StoredSourceNote`, `ReaderLookups`, `FRUSASTNode+PrintedText.swift` and `ReaderRendering.swift`;
  - the old names stay as permanent forwarders;
  - what S8 needs beyond this, figure URLs for the web and the page shell, waits for pull requests of its own.

**The upstream pull request**

Branch `claude/fruscorekit-part1`: eight commits in review order, 72 files, 2,112 lines added and 715 removed. There is no index-version bump, no CloudKit schema change and no new dependency.

- **Moves.** 13 files and 10 suites move with `git mv` and no line changed, so each reads as a 100% rename. They come from `FRUSExplorer/TEI/`, `Citation/`, `CrossReference/`, `Browser/` and `Models/Manifest/`. `project.yml` compiles `FRUSCoreKit/` in both app targets.
- **Splits.** What the kit used from Apple-only files moves in, verbatim:
  - `FRUSURLScheme`: the cross-reference grammar and the figure URL, from the WebKit scheme handler;
  - `HighlightColor`: from the SwiftData highlight model;
  - `FRUSASTNode+PrintedText.swift`, with `StoredSourceNote`: from `IndexingPipeline.swift`.

  Three kit files lose their Apple-only halves to new app files: `VolumeStructure`'s `NavigationPath` overload, `CitationStyle.current`'s `UserDefaults` read and `BrokenRefsIndexStore`'s `Bundle.main` read. Every old name forwards.
- **Guards.** Each takes the old code on an Apple platform:
  - `CryptoKit` falls back to swift-crypto's `Crypto`;
  - `FoundationXML` is imported where it exists;
  - `SourceNoteKit` is imported where it is a module of its own;
  - `CitationPlainText` parses Markdown only where Darwin exists.

  `Linux/LinuxFoundationShims.swift` declares `String(localized:)` and `autoreleasepool` where Darwin is missing, and compiles to nothing on Apple platforms.
- **The reader's path** is public, in `TEI/ReaderRendering.swift`, and the app's reader calls it. The web reader will render through the app's own path, not a copy of it.
- **Public for S8 and S9:**
  - `CrossRefDestination`, stated `Sendable`, since a public enum is not inferred to be;
  - `FRUSURLScheme.resolveCrossRefTarget`;
  - `FRUSCanonicalURL`;
  - `CitationPlainText.plain` and `CitationPunctuation.withoutTerminalPeriod`;
  - every member of `CitableDocumentNumber`.

  The figure URL stays internal, for S8.
- **Eleven dual-compiled suites:** the seven the kit's files had, FootnoteLabelTests, PersonsListEncodingTests and FlushLeftSourcesParseTests, and ReaderRenderingTests, new with the reader's API.
  - Each imports the kit under `swift test` and the app in Xcode.
  - 33 `#if !SWIFT_PACKAGE` guards, each with its reason, keep the app's half in Xcode: 4 around the six suites whose subject is the app, 17 around tests and 12 around statements. The in-app citation suite is guarded test by test, so its caption rules run under `swift test` too.
  - Two tests pin what Linux reaches another way: CitationPlainTextTests copies each style's citation, which Apple platforms do by a Markdown parse and Linux by a marker strip, and the serializer suite checks a broken reference's VoiceOver label, which on Linux goes through the `String(localized:)` stand-in.
  - Under `swift test` they make `FRUSCoreKitTests`: 393 tests in 49 suites.
- **Audits.** `FRUSCoreKitBoundaryTests` (10 tests) reads the kit's source: the app compiles the kit into its own module, so it would build even if a kit file named an app type. The audit fails on:
  - an import other than Foundation outside its `canImport` branch;
  - `Bundle.main` or `UserDefaults`;
  - a type, function, constant or variable of the app's, named outside comments and strings;
  - unguarded code under `Linux/`;
  - a suite that, outside Xcode's branches, imports the app or names a top-level declaration of the app's or of the test target's other files, which Xcode builds and passes and only `swift test` fails;
  - `project.yml` or `Package.swift` dropping the kit.

  Eleven tree-walking audits whose rules a kit file can break now read `FRUSCoreKit/` too, the localized-Markdown census among them.
- **Records:**
  - upstream's `CLAUDE.md`, with a rule: after editing the kit, run `swift build --target FRUSCoreKit` and `swift test --filter FRUSCoreKitTests`;
  - the editable-content pointers, the stale paths and line citations, and CrossRefKit's comments, which no longer claim a parity its hard-coded fixtures never checked;
  - version-history entries and a session entry.

**Results at the pull request's head**

- **Linux, `swift:6.4-noble`, arm64**, in a scratch package that declares the kit as this repository will:
  - A clean build with tests took 25.2 s: "Build complete! (22.45 secs)", with no warning or error line.
  - `swift test list` lists 393 FRUSCoreKitTests. "✔ Test run with 393 tests in 49 suites passed after 0.125 seconds.", with no skips.
- **The renderer on Linux.** A command-line reader that uses only the kit's public API rendered the rows of `fixtures/golden/render/manifest.json`.
  - Debug and release each printed "rows: 392, golden: 392, identical: 392, differ: 0, missing: 0, same order: true".
  - A pass from one `parseVolumeFull` per volume gave "identical 392 of 392" (569 ms debug, 476 ms release).
  - The release build took 24.3 s. Rendering took 40.4 ms per row at the median, 15.9 s in all, with a 38.2 MB peak.
- **The citation rules.** Every newly public citation rule ran over 553 volumes, 3 styles and 4 number shapes: 7,220 lines. The Linux and macOS outputs are byte-identical (sha256 `b2c3dc33…`), and CitationPlainTextTests now holds both ways to the same expectations.
- **The same package natively on macOS**, built clean: "✔ Test run with 393 tests in 49 suites passed after 0.058 seconds.", and the reader rendered 392 of 392 rows identically, in a debug and a release build.
- **macOS, upstream's whole package,** from a clean `.build`:
  - `swift build --build-tests` took 45 s: "Build complete! (43.98 sec)", with 12 warning lines, the same six generator warnings S1 recorded and none from the kit.
  - `swift test` exited 0 in 116 s: 38 runs and 2,056 tests, all passed, none skipped. FRUSCoreKitTests: "✔ Test run with 393 tests in 49 suites passed after 0.061 seconds." 2,056 − 393 = 1,663, S1's count.
- **`FRUSExplorerMac`**, clean, unsigned, Debug: "** BUILD SUCCEEDED **" in 43 s at the head and 44 s at `cfc0d3c`, with identical warning lines (5 lines, the two known residues). The debug dylib defines 233,540 unique symbols at the head and 233,494 on `v2` (`nm -U -j | sort -u`). S1's 238,006 for the same `v2` code counted duplicates: its dylib gives 233,494 unique.
- **iOS**, clean, unsigned `build-for-testing`: "** TEST BUILD SUCCEEDED **" in 143 s at the head and 145 s at `cfc0d3c`, with 7 warning lines each, the two known residues.
- **The full iOS unit run**, unsigned, with the TEI mirror:
  - Head: "✘ Test run with 6484 tests in 763 suites failed after 384.845 seconds with 8 issues."
  - `cfc0d3c`: "✘ Test run with 6470 tests in 760 suites failed after 338.166 seconds with 8 issues."
  - The same 8 tests fail on both, all Keychain `.securityError(-34018)`, since an unsigned test host has no keychain: KeychainStoreTests 5, SettingsTests 2, SourceExplorerTests 1.
  - Both runs skip the same 17 tests and 2 suites.
  - The 14 extra tests are ReaderRenderingTests' 3, FRUSCoreKitBoundaryTests' 10 and CitationPlainTextTests' 1.
- **The audits, mutated.** Planted at once: `import SwiftUI`, `IndexingPipeline`, `UserDefaults.standard` and the app's `frusSubseries(from:)` in `FRUSCanonicalURL.swift`; an unguarded file under `Linux/`; `IndexingPipeline` and the test target's `makeTestPipeline` in `ReaderRenderingTests.swift`, outside its guards; and a `**…**` default in `CitationFormatter.swift`. The app's build still succeeded, and 6 tests failed, each naming the file and line: five of the boundary audit's and the localized-Markdown census. The package fails to build on each of the app's names.
- **The symbol diff** of the two Mac dylibs printed "raw: removed 522 added 568", then "normalized: removed 56 added 105". Every remaining name is expected:
  - the new kit types and members;
  - `normalizedWhitespace`, private before and internal now;
  - the closures of moved bodies;
  - two renumbered thunks;
  - SwiftUI generic metadata over `HighlightColor`, renumbered.
- **Which tree was measured.** The clean builds, the symbol diff, the mutation, and the Linux and native runs are of the head's code before upstream's session entry had its numbers; the head differs from that tree in `Planning/DEVELOPMENT-PLAN.md` alone, which nothing builds or reads. At the head itself, `8498587d`, the full iOS unit run above was made with the app removed first, and `swift test` on macOS and the Linux tests and release render were repeated, with the same results.

**Delivered here**

- **The source digest takes in `FRUSCoreKit` once the pin has it.** `UpstreamDigest.directories` lists `FRUSCoreKit`, and a listed directory with nothing at its path contributes nothing. So the digest at `cfc0d3c` is unchanged, and the committed golden files stay current. Anything else at a listed path must be a directory that can be read: a file, or a link pointing nowhere, is an error, never skipped. A submodule holding none of the directories, as an uninitialized one does, is an error too.
- **`tools/mac-golden` compiles `FRUSCoreKit` once the pin has it.** Its manifest lists the kit and compiles only the listed directories the submodule has.
  - A committed link to `FRUSCoreKit` would point nowhere until the pin moves, and SwiftPM warns about a link that points nowhere ("ignoring broken symlink"), even when it is excluded ("Invalid Exclude … File not found").
  - So the six per-directory links in `Sources/FRUSExplorer` become one, `upstream`, to the submodule, which exists at every pin. The manifest excludes the submodule's other top-level entries, as well as everything in the compiled directories that is not Swift.
- **Tests.** A new ProvenanceTests test covers the missing directory:
  - an absent `FRUSCoreKit` leaves the digest unchanged, and so does an empty one;
  - moving a file into it changes the digest, as the pin move will;
  - a file or a dangling link in its place is an error, and so is an empty or absent submodule.

  The old test's last step, which held that a missing directory is an error, gave way to it. With the skip removed, 18 of FRUSParityTests' 58 tests fail at `cfc0d3c`: this one, the check of the committed golden files, and the tests that summarize a database or validate golden files, since both compute the digest.

**Results here**

- **Linux, `swift:6.4-noble`, arm64.** A clean build with tests: "Build complete! (43.63 secs)", with no warnings. 725 tests: 724 pass, and the one skip is the named one. FRUSParityTests has 58, one more than before. CI's Test-step guard, run from `ci.yml` in the container, passes, and so does No runtime skips.
- **macOS, natively.** The same 725 tests pass, none skipped.
- **At `cfc0d3c`, in this worktree:**
  - `frus-parity check-golden` passes.
  - The digest is `a5bd78c2…`, the committed `sourceDigest` of both golden files. A Python recomputation gives the same, over 604 files.
  - A clean `tools/mac-golden` build: "Build complete! (40.47 sec)", with one warning, the app's known `GeneratedSummary` residue. The app module compiles the same 521 files as before, plus the stub.
  - `render` printed "render: 392 rows, 3554115 bytes of HTML". The HTML is byte-identical to the committed files, the rows match in order, and every provenance field is equal.
  - `expressions` wrote a byte-identical `queries.expressions.json`.
- **At the upstream head `8498587d`, in a scratch clone of this branch:**
  - The same manifest compiles 529 app files, 18 of them in `FRUSCoreKit`: "Build complete! (45.16 sec)" from clean, with the same one warning.
  - The HTML of all 392 rows is byte-identical to the committed files.
  - `scripts/make-golden`, with the head recorded as the pin, passed `check-golden`. Only provenance changed: `upstreamCommit` and `sourceDigest`, in `render/manifest.json` and `queries.expressions.json`, four lines.
  - The digest there, `39d9aed1…`, covers 612 files. Without `FRUSCoreKit` in the list it would have covered 594, missing the kit's 18.

**The pin-move pull request, after the merge**

- **`Package.swift`.** `FRUSCoreKit` (depending on SourceNoteKit, and on swift-crypto's `Crypto` for Linux only) and `FRUSCoreKitTests`, from the working manifest in the upstream pull request's description.
- **A check 4 test.** It renders all 392 golden rows on Linux through the kit's public API alone, and compares each byte for byte with `fixtures/golden/render`:
  1. `parseDocument`;
  2. `ReaderLookups` from the volume's persons and terms;
  3. `init(readerOf:lookups:brokenRefs:)` with the bundled broken-refs index;
  4. `FRUSRenderNodeHTMLSerializer.reader`.

  The upstream pull request's command-line reader did exactly that, for 392 of 392.
- **Check 7's formatter and parser half in CI**, inside FRUSCoreKitTests: the eight suites `CitationFormatterTests.swift` compiles under `swift test` (32 tests), CitationParserTests (26) and the three suites in `PageSpanResolverTests.swift` (23), 81 in all.
- **CI.** The count per target gains FRUSCoreKitTests, 393. The skip guard needs no change: the kit's suites skip nothing on Linux, no line of their log matches its pattern, and none calls `Test.cancel`.
- **Golden files.** `scripts/make-golden` on the owner's Mac at the merged commit. Only provenance may change, as rehearsed above. `tools/mac-golden` and the digest need no edit.

**Notes**

- **CI time, from PR #15** on GitHub's amd64 runner:
  - the `swift` job took 568 s, the Test step 384 s, and FTS5StoreTests 372 s of that;
  - the Build step took 71 s, from a restored cache, and the `compose` job 271 s.

  The scratch package with the kit, SourceNoteKit and swift-crypto built clean in 25.2 s on Linux arm64, and the kit's tests take well under a second, so the job stays far inside its 45-minute limit.
- **Two older issues** are listed in the upstream pull request for the owner to file:
  - CrossRefKit's grammar has drifted from the app's: its hard-coded fixtures expect `.document` for `#d100fn2`, where the app has returned `.footnote` since #988, and it does not treat a `mailto:` target as external. The upstream pull request's comments now say so instead of claiming parity. S8 should resolve cross-references with `FRUSURLScheme.resolveCrossRefTarget`, the app's own, now public.
  - `CitationPlainText` parses Markdown on Apple platforms and strips the paired markers on Linux. The two agree on all 7,220 lines above, and CitationPlainTextTests holds both to the formatters' own output, but a title with other Markdown syntax could print differently in S9's Cite.
- **One behaviour moves:** `BrokenRefsIndexStore.shared` is read when the reader's converter is built, not at the first cross-reference. It loads once per launch either way.
- **What was not run upstream:** a signed iOS run, since every run in the session was unsigned. The intermediate commits were not built one by one; upstream squash-merges.
- **`docs/prep/`.** `s3-linux-edits.tsv` is superseded by the upstream pull request, which makes those changes upstream, and so are the autoreleasepool and `String(localized:)` shims in `shims/`, by its `FRUSCoreKit/Linux/LinuxFoundationShims.swift`. `shims/KeychainShim.swift`, the `KeychainStore` stand-in, stays as S6's reference, to go upstream with S6's pull request. The shims never enter this repository's code. `PLAN.md` records the owner's decisions and Mac check 2. It now has a Mac check between S3 and S4, and splits check 7 between S3 and S6.

**Next.** The owner's Mac check 2 and merge of the upstream pull request, then the S3 pin-move pull request above. After it, the owner's three-volume export for the Golden files checkpoint. S6 follows, with the indexer, search and check 7's matcher half.

## Pin move: the six kits on Linux in CI

4 October 2026 · branch `claude/pin-cfc0d3c` · upstream [joshbotts/FRUS-Explorer#1567](https://github.com/joshbotts/FRUS-Explorer/pull/1567), merged as `cfc0d3c`

The owner ran Mac check 1 and squash-merged #1567 as `cfc0d3c`, the only commit on `v2` after `34a5120`. This is the pull request Session 1's entry describes: it moves the pin, adds the three kits the guards made portable, and lets CI allow the one named skip. The index version stays 65, the FTS schema 4 and the app build 49.

**Delivered**

- **The pin** moves from `34a5120` to `cfc0d3c` (rule 5). The submodule has no local changes.
- **`Package.swift`.**
  - The whole of FTS5Store replaces the `FTS5Schema` target, which compiled only its four pure-Swift files. Every dependency on that target, and the four files that imported it, now name `FTS5Store`. The module still holds a type called `FTS5Schema`, so `FTS5Schema.frusDocuments` reads as before.
  - New targets: TEIHeaderKit; ManifestGeneratorCore and ManifestGeneratorTests, which hold TEIHeaderKit's tests; SemanticVectorsKit and its tests; and FTS5StoreTests.
  - The guards' dependencies are Linux-only: `CSQLite` for FTS5Store and its tests, and swift-crypto's `Crypto` for SemanticVectorsKit. swift-crypto was already a dependency, so `Package.resolved` is unchanged.
  - sqlite3 is linked from one place on each platform. On Linux, `CSQLite`'s module map links it. The SDK's `SQLite3` module links nothing, so upstream's `linkedLibrary("sqlite3")` stays, for macOS only. Each test binary that uses SQLite depends on `libsqlite3` once, on both platforms.
  - The server and FRUSLightCore depend on none of the kits.
- **`ci.yml`.**
  - The Test step's skip guard allows one skip by name: FTS5StoreTests' "Database file has isExcludedFromBackupKey set after creation", skipped with a reason that begins "Linux: ". It is the named Linux-only skip SPEC's check 1 allows. Any other skip fails the job, from a trait or XCTSkip, and so does a test or suite that cancels itself with `Test.cancel`, or this test skipped for another reason. The named skip must appear exactly once. The log names no suite, so a second test with the same name would otherwise pass, and its absence means the test now runs or the log's format has changed. The guard reads the log with `grep -a`, so a NUL byte in a test's output cannot hide the lines after it.
  - A new step, No runtime skips, fails if any target in `Package.swift` calls `Test.cancel`. When it cancels one case of a parameterized test, the log has no line for it and the test is reported as passed, so the Test step cannot see it. No target calls it at `cfc0d3c`. The step reads the targets' directories from `swift package dump-package`.
  - The `swift` job's time limit is 45 minutes, as the `compose` job's is, up from 30 (see Timing).
- **Golden files.** `scripts/make-golden` ran at `cfc0d3c` on the owner's Mac, in 71 seconds. The HTML of all 392 rows (3,554,115 bytes) and the expressions of all 482 queries are byte-identical to `34a5120`'s. Only the provenance changed, in `render/manifest.json` and `queries.expressions.json`: `upstreamCommit`, and `sourceDigest`, since the guards change files inside the digest. `check-golden` passes. `PENDING` still lists the two files that wait for the owner's export.

**Results**

- **Linux, `swift:6.4-noble`, arm64.** A clean build with tests took 77 seconds, with no warnings. Of the 724 tests, 723 pass, and the one skip is the named one:

  | Target | Tests |
  | --- | --- |
  | SourceNoteKitTests | 292 |
  | FTS5StoreTests | 209 |
  | ManifestGeneratorTests | 60 |
  | SemanticVectorsKitTests | 35 |
  | CrossRefKitTests | 10 |
  | GeneratorKitTests | 7 |
  | FRUSParityTests | 57 |
  | FRUSLightCoreTests | 42 |
  | FRUSLightServerTests | 9 |
  | FTS5CheckTests | 3 |

  The six kits hold 613 of them, as S1 counted at the pull request's head.
- **macOS, natively.** The same 724 tests, with the same counts per target, all pass with none skipped. The backup-exclusion test runs there, and passes. A clean build took 52 seconds, with no warnings.
- **The guard, tested.** The Test step's script, read from `ci.yml`, ran in the swift image under `bash -eo pipefail`, as Actions runs a step, with `LANG` unset and set to `C.UTF-8`. It ran against the real Linux logs from arm64 and amd64, and against altered copies of them. A probe package in the image printed the real line for each kind of skip and cancellation.
  - It passes on both real logs, where the named skip appears once.
  - It fails with no skip at all. It fails when an extra skip sits beside the named one: a test with a "Linux: " reason, a test with no reason, a suite, or an XCTest case. It fails on a test or suite cancelled at runtime, with a reason or without, and on an extra skip after a NUL byte or after invalid UTF-8.
  - It fails when the named test is skipped for another reason, and when a skipped test's name is the named one with a prefix or a suffix. It fails on a second skipped test with the same name, and on two skips torn onto one line.
  - An earlier draft of the guard, without `-a`, the cancelled form or the count, passed with a cancelled test or suite, a second test of the same name, two skips on one line, or a skip after a NUL byte.
  - No runtime skips passes on this branch. It fails when `Test.cancel` is added to a kit's tests, to the web tests or to a library, and when `Package.swift` does not compile. It passes when the call is in a target this package does not build.
- **Timing.** Testing took 111 seconds on Linux arm64, 96 of them in FTS5StoreTests, whose exhaustive query-combination suites dominate; macOS took 102. GitHub's `ubuntu-24.04` runner is amd64 with 4 vCPUs, so the suite was also measured on amd64: in linux/amd64 `swift:6.4-noble` under Rosetta on this Mac, limited to 4 CPUs, a build with tests and no cache took 709 seconds, with no warnings, and testing took 331, 309 of them in FTS5StoreTests. All 724 tests ran there, with the same counts per target, and the guard passes on that log. A runner's vCPU is probably no faster than Rosetta on this Mac, so a run with no cache could come near the old 30-minute limit, and the limit is now 45.
- **The image is unaffected.** `scripts/compose-smoke` passes. The image's build compiles FRUSLightCore and the server and no kit, and the image is still 251 MB.

**Notes**

- **swift-build crashed once on Linux,** with signal 11 while planning the build, in its target-triple parsing on a worker thread. The same command then built. If CI's Build step ever fails that way, run it again.
- **The guard matches text.** A passing test whose display name contains "skipped" also matches `(Test|Suite) .* (skipped|was cancelled)`. No target built here has one, but upstream has 32 in 23 files at `cfc0d3c`. Nine are in its package's generator tests: RefHarvesterTests, POCOMIndexBuilderTests, and the LotClaimants, RecordGroupCatalog and SourceNoteEval generators' tests. The other 23 are in FRUSExplorerTests, among them IndexingPipelineTests, which S6 may compile. A session that adds such a target will see the guard fail, which errs the safe way. It must then narrow the pattern, for example to the forms Swift Testing prints: `skipped: "`, a closing `skipped.`, and `was cancelled after`.
- **The owner's next Mac build comes from `cfc0d3c`,** for the Golden files checkpoint and the S10 export, as `PLAN.md` says for a pin move. The guards change no code on Apple platforms, and the index version is still 65.
- **Mac check 1 is Done** in `PLAN.md`'s owner checkpoints.

**Next.** S3, the TEI renderer and Citation, is under way alongside: its upstream refactor is larger, and `docs/prep/README.md` lists what it needs. The owner's Golden files checkpoint still waits for a three-volume export.

## Session 1: the shared kits on Linux

4 October 2026 · branch `claude/s1-linux-guards` · upstream [joshbotts/FRUS-Explorer#1567](https://github.com/joshbotts/FRUS-Explorer/pull/1567)

The owner lifted the hold on upstream pull requests on 4 October. S1 opened the first one, as decided on 3 October: this session builds and tests the six kits against that pull request's head, and records the result here. After the owner's Mac check and merge, a separate pull request moves the pin and adds the kits to CI.

**Delivered**

- **The upstream pull request**, from `v2` at `34a5120`, which is still the pin: `v2` had not moved since 3 October. It contains:
  - **Import guards in 14 files.** `SQLite3` falls back to this repository's `CSQLite`, `CryptoKit` to swift-crypto's `Crypto`, and `OSLog` is imported only where it exists. `FoundationXML` and `FoundationNetworking` are imported only where they exist, which is not on Apple platforms.
  - **`URLSession.bytes(for:)` on Linux.** swift-corelibs-foundation lacks it, so on Linux `TEIHeaderFetcher` reads the response whole and replays it into the same scan.
  - **`FTS5Store/LinuxLogger.swift`**, a stand-in for `os.Logger`, compiled only where `OSLog` is missing, with upstream's licence header. Without the header, upstream's coding-standards audit would have failed the Mac check: the prepared patch in `docs/prep/` lacked it.
  - **Six `project.pbxproj` lines** from `xcodegen` for the new file, in both app targets.
  - **One named Linux-only skip.** FTS5StoreTests' backup-exclusion test is disabled where Darwin is missing, with the reason "Linux: swift-corelibs-foundation keeps no backup attribute, so excluding a file from backup is a silent no-op". It still runs on Apple platforms. This is the skip SPEC's check 1 asks to be named.
  - **Upstream's records:** version-history lines and a session entry in its `Planning/DEVELOPMENT-PLAN.md`.

**Results at the pull request's head**

- **Linux, `swift:6.4-noble`, arm64.** A local copy of this package, with the six kits' targets added and the submodule at the pull request, built with no warnings. All six kits' tests pass: SourceNoteKitTests 292, FTS5StoreTests 209, ManifestGeneratorTests 60 (which hold TEIHeaderKit's 22), SemanticVectorsKitTests 35, CrossRefKitTests 10, GeneratorKitTests 7. That is 613 tests. The one skip is the named one. At `34a5120`, each of the three kits stops at its first Apple-only import.
- **macOS, the same package:** 613 tests pass, none skipped.
- **Apple platforms compile what they did before.**
  - A `canImport` probe shows each guard taking its old code on the macOS, iOS Simulator and iOS SDKs.
  - A clean `FRUSExplorerMac` build gives the same warnings as `v2`, and a debug library defining the same 238,006 symbols.
  - The iOS unit target passes 6,470 tests in 760 suites, with the same 17 skips as `v2`.
  - Upstream's whole package passes under `swift test`: 1,663 tests in 37 runs.
  - One reader test fails from a cold simulator on `v2` too; the pull request leaves it for the owner to file.

**The pin-move pull request, after the merge**

- **`Package.swift`.**
  - FTS5Store replaces the `FTS5Schema` target, since two targets cannot compile the same files, and the four files that import `FTS5Schema` import `FTS5Store`.
  - Add TEIHeaderKit, ManifestGeneratorCore and its tests, and SemanticVectorsKit and its tests.
  - `CSQLite` and swift-crypto are Linux-only dependencies of the kits that need them.
  - The working manifest is in the upstream pull request's description. None of this can land before the pin moves: at `34a5120` FTS5Store does not build on Linux.
- **`ci.yml`.** Its skip guard allows the one named skip by name. As it stands, the guard fails on that line.
- **Golden files.** `scripts/make-golden` on the Mac at the merged commit: the guards change files inside the digest. A trial run gave byte-identical HTML and expressions, so only their provenance changes.

**Notes**

- **Mac check 1** now runs `swift test` too, from a clone at a real path. Xcode's schemes never run the kits' own test suites, and under `/tmp` six of upstream's source-scan tests fail falsely. The pull request lists the commands.
- **Nothing upstream keeps the guards alive.** Upstream has no CI, so a new unguarded Apple-only import in one of these kits would break the web build unseen, until the next pin move. The pull request offers the owner a line for upstream's `CLAUDE.md`.
- **On Linux, the logging shim prints every level to standard error,** debug included: FTS5StoreTests prints about 200 debug lines. S6 may want to quiet it.

**Next.** The owner's Mac check 1 and merge of #1567, then the pin-move pull request. S3 can start alongside: its upstream refactor is larger, and `docs/prep/README.md` lists what it needs.

## Import mode: unfinished journals and symbolic links

4 October 2026 · branch `claude/import-journal-symlinks`

Session 4's review found two gaps in its index summary, both fixed there. Import mode had the same two:
- It opens an export with `immutable=1`, which never rolls back a hot rollback journal, so a copy left mid-transaction would have been imported half-written.
- The drop zone skipped a symbolic link without a word, so a link that `docker compose cp` copied in sat in `/data/import` while `/readyz` still asked for an export. The importer, called directly, followed a link.

**Delivered**

- **Unfinished transactions.** An export arriving with a `-journal` file that may hold an unfinished transaction is refused, like one with a `-wal` file. The test is SQLite's own: the journal is not empty and its first byte is not zero, and one that cannot be opened or read counts as hot. Anything else in the journal's place, such as a link or a FIFO, counts too and is never opened. An empty or zeroed journal holds nothing to roll back and is accepted. Both refusals now say to remove the side file first, then copy in a fresh export: the side file would get the fresh export refused too.
- **Symbolic links.** A link in the drop zone is refused before anything reads through it, and not tried again until it changes. `docker compose cp` copies a link as a link, usually to a path that exists only on the host. The message says to copy the export itself with `docker compose cp -L`. The importer refuses a link too, in case anything else hands it one.
- **Links are seen, not skipped.** The scanner keeps a symbolic link as well as a regular file, reading the link's own attributes and never its target's, so the link is refused out loud on Linux and macOS alike.
- **`docs/INSTALL.md`.** Its table of refusals has both new messages.

**Results.** FRUSLightCoreTests has 5 new tests, 42 in all, covering:
- a journal holding an unfinished transaction;
- a journal that cannot be judged: a link to nowhere, a link to a zeroed journal, a FIFO and an unreadable file;
- an empty journal and a zeroed one;
- a link to an export, and a link pointing nowhere, both in the importer and in the drop zone, which reports a link once.

All pass on Linux arm64 and natively on macOS, with none skipped. Against `main`'s code, the journal test and both link tests fail; the test that accepts an empty or zeroed journal passes, as it should.

**Review.** An adversarial review confirmed 8 findings, all fixed. The main one: a journal the server could not open counted as harmless, the opposite of SQLite's rule, so a half-written copy could have been imported. A FIFO in the journal's place would have hung the importer. The install guide's advice for a link would have deleted the export just copied.

**Next.** Unchanged: the owner's Golden files checkpoint. S1, S3 and S6 wait for upstream pull requests.

## Session 4: the parity harness

3 October 2026 · branch `claude/s4-parity-harness`

S4 builds what checks 2–4 compare, and already runs on Linux the part of check 3 that needs no further upstream code. The owner decided three things on 3 October:
- S4 copies no upstream code, so renderer parity on Linux waits for S3 (rule 4).
- Check 3 passes when results differ only in the order of documents whose Mac scores are exactly equal, and reports each such group.
- The golden files that depend only on the app's source are made in the session, on the owner's Mac. The owner makes the two that need an export.

**Delivered**

- **Golden-file formats** (`Tests/ParityFormat`), shared by the Linux harness and the Mac tool. Each golden file records the tool that made it, the upstream commit, the app build (49), the index version (65), a digest of the app's sources and resources in the submodule, a digest of each input, and the platform. The inputs are the fixture TEI, the query list's queries (not their notes, so editing a note changes nothing) and, for the two files made from an export, the export's `research_provenance` stamp. A test recomputes the digests, so a golden file made from other app sources or resources, another query list or other fixtures fails as stale. The two export-based files must come from one export made by the pinned app build.
- **`tools/mac-golden`**, a Mac-only tool that runs the app's own code. Its package compiles the whole app module unmodified: all 520 Swift files, through six directory symlinks into the submodule, plus a one-line stub for an asset symbol that Xcode generates and SwiftPM does not. It needs macOS 26, because the app uses FoundationModels, and a debug build, because it imports the app with `@testable`. A clean build takes 45 seconds. CI does not build it.
  - `render` takes every row a full parse of each fixture volume yields and runs the Mac reader's own path: `DocumentViewModel.load`, then `HTMLTemplate.build`. It keeps the fragment inside `<body>` and copies none of the app's settings.
  - `expressions` runs SearchService's `parsedQuery(for:)`, `matchExpressions(for:)` and `exactTerms(from:)` over a throwaway empty database. The records are the same over a fixture index.
  - `results` runs `searchCount` and the first 50 results over a copy of an export, recording each score's bits. It refuses an export that is not exactly the three fixture volumes, that holds the owner's writing, or that has another index version. It also records the results after the 50th that tie with it, so a tie group crossing position 50 is known whole.
- **`frus-parity`** (`Tests/FRUSParity`, `Tests/FRUSParityTool`), on Linux and macOS:
  - `summarize` writes check 2's summary of a `frus.db`. It opens the file read-only and immutable, and hashes each table's rows with SHA-256 in natural-key order, framed as SQLite's `sha3_query` frames them, recording each statement's SQL.
    - It leaves out whatever depends on indexing history: rowids and other surrogate ids (a person rollup is named by its least member), the key order of `volume_structures`' JSON (read through `json_tree`), and the FTS5 segment layout. For full-text tables it compares `_config`, the averages record, `_docsize` by document, and the vocabulary.
    - The order of rows within a volume gates only for `document_cache`, `page_ranges` and `cross_references`, which the app reads in that order. `person_mentions` and `person_list_sources` are built from Swift sets, so their order changes from run to run.
    - It refuses an export that is not exactly the three fixture volumes (unless given `--any-volumes`), one with writing, one with another index version, one with a `-wal` file or an unfinished rollback journal beside it, one with a stale person rollup, and one holding any schema object it cannot classify. It also refuses fixture TEI that does not match `SHA256SUMS`. A path through a symbolic link is checked as the file it points to.
  - `compare-summary` compares two summaries.
  - `parse` prints the Linux parse of the query list.
  - `check-golden` validates `fixtures/golden`.
- **The query list** (`fixtures/parity`): 482 queries over 69 rules. R01–R46 follow the manual's §7.2 in order, with its examples verbatim. R47–R69 cover stemming, ranking, scopes, filters, dates, document types, front matter and the tokenizer. Re-deriving §7.2 found one rule the first draft missed: a phrase typed without inner quotation marks still matches text that prints them.
- **Golden files made in this session** (`fixtures/golden`):
  - the HTML of all 392 fixture rows, 3.55 MB;
  - the compiled expressions of all 482 queries.

  `fixtures/golden/PENDING` lists the two still to come from the owner's export: `index-summary.json` and `queries.results.json`.
- **`scripts/make-golden`**, the owner's script, in the style of `scripts/mac-check`. It builds the tool and writes the golden files that need only the app's source. With `--export`, it also writes the export-based ones from a temporary copy of the export. Then it runs `check-golden` and leaves the commit to the owner.

**Results**

- **Tests.** FRUSParityTests' 57 tests pass on Linux arm64 and natively on macOS, with no warnings and none skipped. The other targets are unchanged (358 tests).
- **Check 3's parse runs on Linux now.** For all 482 queries, the parser compiled on Linux gives the same expression, exact terms, operands, dropped operands and flags as the app's SearchService on the Mac. For the 457 queries in the default scope, it also gives the same compiled expressions. Comparisons are byte for byte. CI adds amd64.
- **The summary does not depend on SQLite's version.** Two three-volume databases were built from the owner's export, with the volumes in different orders and the rollup renumbered. They gave identical gating hashes on macOS (SQLite 3.54.0) and on Linux (3.45.1). The full 2.83 GB export took 19 seconds to summarize natively, read-only, using 38 MB of memory.
- **The render is stable.** Two runs, another build, and other time zones and locales all gave byte-identical HTML. It matches, for all 392 rows, the research build that used the reader's settings. The fields the reader is opened with do not change it; the tool checks that on every 25th row.
- **Ties are common.** On a three-volume index, 72 queries have exactly tied scores in their top 50, and 12 have a tie group crossing position 50. `results` was tested on a research copy built from the owner's export, not on a new export.

**What waits**

- Index parity (check 2), and check 3's counts and results, need the Linux indexer and SearchService (S6), and the owner's golden files.
- Renderer parity (check 4) on Linux needs the TEI pipeline (S3).
- The 25 queries outside the default scope wait for SearchService on Linux (S6), because their compiled expressions depend on its scope logic. 14 compile column-scoped expressions, 7 compile the unscoped parse for one table only, and 4 are refused.

**Review.** An adversarial review confirmed 17 findings, some overlapping. All are fixed, and each fix to the Swift code has a test that fails without it:
- a database reached through a symbolic link skipped the `-wal` check and the size limit, and `mac-golden` opened such a link read-write in place;
- an unfinished rollback journal went unnoticed;
- comparisons used Swift's `==`, which takes canonically equivalent text as equal;
- the staleness digest missed bundled resources, such as the broken-references index that changes the reader's HTML;
- the export-based golden files were not tied to the fixtures, to the pinned build or to each other;
- editing a query's notes would have made the golden files stale;
- the compiled-expression half of the golden file was never compared;
- `index-summary.json` would not have recorded the upstream commit.

**Notes**

- **Docker Desktop hung for about two hours.** A research container mounted the owner's export from `~/Documents`, and macOS held the mount behind a privacy prompt. No container started until the owner answered it. Nothing mounts `~/Documents` now; `scripts/make-golden` copies the export to a temporary folder first.
- **The Mac tool is outside CI.** A pin move can break it unseen until the next golden refresh, which `scripts/make-golden` then reports. The pull request that moves the pin must carry refreshed golden files, or its `swift` check fails.
- **Import mode has the same gap the review found here.** `IndexImport` checks only for a non-empty `-wal`, not for an unfinished journal, and does not resolve symbolic links. It is outside S4; it is flagged for a later session.
- **Each summary has its own timings.** A regenerated `index-summary.json` always differs in its `information.timings` section.

**Next.** The owner's Golden files checkpoint: a Mac library holding exactly the three fixture volumes, an export from it, then `scripts/make-golden --export`. `docs/prep/README.md` advises doing it once, after the public release. S1, S3 and S6 wait for upstream pull requests; until then, phase 1's server track has no further session that runs without them.

## Session 7: the published image and the install guide

3 October 2026 · branches `claude/s7-image-install`, `claude/s7-after-publish` and `claude/s7-trial`

**Delivered**

- **`.github/workflows/image.yml`.** On every push to `main` it publishes `ghcr.io/joshbotts/frus-explorer-light` in four jobs:
  1. Each architecture builds natively and in parallel: amd64 on `ubuntu-24.04`, arm64 on `ubuntu-24.04-arm`, free for public repositories. Each pushes by digest.
  2. A second job joins them under `sha-<commit>`, the commit's first 7 characters.
  3. A third pulls that tag and runs the Compose smoke test on both architectures.
  4. Only then does a fourth move `edge` to it.

  Rule 7 holds in two places: on a pull request that changes the image, the server or the submodule, both architectures build and nothing is pushed; a manual run publishes only from `main`. Each job gets only the permissions it needs, the actions are their Node 24 releases (as are `ci.yml`'s), and the image carries version and revision labels.
- **`docs/INSTALL.md`** covers a Mac and a Linux host: getting `compose.yaml`, the TEI folder (FRUS Explorer's own on a Mac once Docker Desktop may read it; a shallow HistoryAtState/frus clone on Linux), starting, exporting with the app's exact menu and option names, importing, what each `/readyz` step means, each kind of refusal and its fix, clearing the drop zone, upgrading, removing, and the settings.
- **`compose.yaml`.** Gotenberg is now behind a `pdf` profile. Nothing uses it before phase 3, and it is a 700 MB download.
- **The owner's decisions,** recorded in `PLAN.md` (and its shared copy, rev 51): the image is public, and the TEI sources are as above.

**A rehearsal of the guide on the owner's Mac.** It used the image built locally under the published name, which was removed afterwards so that it cannot shadow the real one:
- `compose.yaml` in its own folder, with `FRUS_TEI_DIR` in `.env` pointing at FRUS Explorer's folder: 553 TEI files and 96 figure folders, read-only;
- `docker compose up -d` started the server alone;
- the owner's real export was ready 37 seconds after `docker compose cp` began;
- memory peaked at 128 MiB, against SPEC's estimate of 4 GB, and the index takes 2.8 GB (2.7 GiB) in the volume.

**After merge**

- **The first publish.** `image.yml`'s run on `main` passed all six jobs in under six minutes: both builds, the join, the smoke test on both architectures, then `edge`. `edge` and `sha-7ecf0c9` name the same image index, for amd64 and arm64.
- **Public from the start.** The package came out public and linked to the repository. The settings change planned here was not needed.
- **An anonymous pull.** The `edge` manifest was fetched with an anonymous registry token. `docker pull` then ran with an empty Docker config on the owner's Mac. It got the arm64 image, 251 MB, labelled with revision `7ecf0c9`; `--version` answers `frus-light 0.1.0-dev`.
- **The macOS setting.** `INSTALL.md` now names the exact macOS setting, from the owner's screenshot on macOS 27. It also says what to do if Docker is not listed there yet.
- **The owner's Mac trial,** S7's done-criterion, followed the guide with the published image and found nothing wrong in it. `/readyz` answered `200`, serving 316,768 documents from 553 volumes at index version 65. Docker Desktop already had the Files & Folders permission, so the guide's advice for a Mac where Docker is not listed yet is untested.
- **What ready looks like.** `INSTALL.md` now says that `/readyz`'s ready answer gives the number of documents and volumes served.
- **`main` requires `compose` too.** Pull requests into `main` now need both CI jobs, `swift` and `compose`, to pass. Both run on every pull request.

**Next.** S8, the search, browse and document endpoints, joins both tracks: it needs the Linux indexer and search (S6), which wait for upstream pull requests. S4, the parity harness, needs no upstream changes. S9, the browser app, depends on S8.

## Session 5: the image and a Compose smoke test

3 October 2026 · branch `claude/s5-image-compose`

**Delivered**

- **`docker/Dockerfile`.** Two stages:
  - The build stage makes a release build in `swift:6.4-noble` with the Swift runtime linked in (`--static-swift-stdlib`). It uses SwiftPM's native build system, which SwiftPM marks deprecated, because with Swift 6.4's default (swiftbuild) that link leaves Foundation's CoreFoundation and ICU symbols unresolved. Explicit linker flags did not help. Revisit with the next Swift release.
  - Its SwiftPM cache mount, which speeds up local rebuilds, is one per architecture and locked, so concurrent or two-platform builds cannot share a build database. `.dockerignore` keeps docs, scripts, CI and the submodule's `Planning`, `Docs` and `Vendor` folders out of the build context.
  - The runtime stage is Ubuntu 24.04 with `libsqlite3-0` (3.45.1, FTS5), `libstdc++6`, CA certificates and `tini`. The server runs as UID 10001, and `/data` belongs to that user, so a new named volume starts with that ownership. The image is 251 MB.
  - A `HEALTHCHECK` runs `frus-light --check-health`, which asks the server's own `/healthz` over a socket, since the image has no curl. It tries 127.0.0.1, then ::1 when nothing listens on IPv4, and prints the status line or the error for Docker's health log. A listener that never answers costs one 3-second timeout, inside Docker's 5 seconds, and a reset connection cannot kill it with SIGPIPE.
  - A server that cannot write its data directory, such as a host folder owned by another user, now says it must be writable by its UID.
  - The encoder (phase 4), the web client (S9), `FRUSExplorer/Resources` (S8) and `rclone` (runtime options) arrive with the work that needs them.
- **`compose.yaml`.** The plan's file, with these additions:
  - `read_only: true` and a `/tmp` tmpfs, as SPEC's Security section asks;
  - every Linux capability dropped, and `no-new-privileges`;
  - `FRUS_IMAGE`, to run another image;
  - `FRUS_TEI_DIR`, defaulting to `./tei`;
  - `FRUS_HOST_PORT`, defaulting to 8080.

  It leaves out SPEC's `FRUS_ENCODER` (phase 4) and the secret key file, since phase 1 stores no keys. Until S7 publishes the image, its header shows how to build it under the default name. SPEC's Licensing asks for a `NOTICE` in the image; the repository has none yet, so only `LICENSE` ships.
- **`scripts/synthetic-export`.** It writes a small valid export from the real schema with the host's `sqlite3`, reading the index and FTS schema versions from `Compatibility.swift`.
- **`scripts/compose-smoke`.** It starts the Compose server and checks that:
  - it runs as UID 10001;
  - the root filesystem and the TEI folder are read-only, tested as root so that the mounts are tested rather than the server user's permissions, while `/data` and `/tmp` are writable;
  - the port is published on 127.0.0.1 only;
  - `/readyz` answers 503 before an import;
  - after `docker compose cp` of a synthetic export, `/readyz` answers 200 and the status reports 3 documents;
  - the container reports healthy;
  - after a restart, the index is still served.

  It runs the same locally and in CI.
- **`ci.yml`.** A `compose` job builds the image with Buildx, caching layers between runs, and runs the smoke test.

**Import mode, one addition.** `docker compose cp` keeps a file's mode, so an export saved 0600 arrives unreadable to UID 10001. It used to sit in `/readyz` as "still copying" forever. Now `/readyz` says the server cannot read it, names the fix (`docker compose cp -a`, or a `chmod`), and the file is tried again every minute.

**Results.** The smoke test passed locally against the arm64 image, and in review against an amd64 build made under emulation. The Swift targets pass on Linux and macOS with no warnings: FRUSLightCoreTests 37, and FRUSLightServerTests 9, with a test of the health check against a live server. The owner's real 2.83 GB export, copied in through Compose with `FRUS_TEI_DIR` pointing at the HistoryAtState/frus clone, was ready 37 seconds after the copy began, with all 744 TEI files visible read-only and the container healthy.

**A finding that changes the plan.** Docker Desktop cannot mount FRUS Explorer's own TEI folder. macOS refuses it with "operation not permitted", because it keeps other apps out of an app's container, so the plan's Compose sketch failed at `docker compose up`. `compose.yaml` now mounts `./tei` by default; nothing reads TEI files until the reader in S8. `docs/PLAN.md` (and its shared copy, rev 50) and `docs/prep/README.md` record the options for the owner to choose before S7:
- a HistoryAtState/frus clone, with the same TEI XML but not the 96 folders of figure images the app downloads;
- the app's folder, once Docker Desktop is allowed access to other apps' data;
- fetching from GitHub on first open, which SPEC allows.

**Notes**

- The `compose` check is not yet required on `main`; the owner can add it once it has run.
- The health check tries 127.0.0.1, then ::1, so a server bound to either answers.

**Next: S7.** The published image and `docs/INSTALL.md`. It needs two decisions from the owner: where TEI files come from, and whether the image is public. S4, the parity harness, can run first.

## Session 2: the server and Import mode

3 October 2026 · branch `claude/s2-server-import`

S1 waits. The owner asked that sessions not open pull requests on `FRUS-Explorer` for now, so the server track went first. Like S0, this session ran on the owner's Mac.

**Delivered**

- **The server.** `FRUSLightServer` is a Hummingbird 2.27 server with three endpoints:
  - `/healthz` answers as soon as the process runs.
  - `/readyz` returns 503 naming the current step, and 200 once an index is open.
  - `/api/v1/status` reports the versions, SQLite's version, the index summary, and an import's progress and outcome.

  `--version` still prints the version.
- **Configuration.** The phase-1 variables in SPEC's table are read: `FRUS_MODE`, `FRUS_AUTH`, `FRUS_DATA_DIR`, `FRUS_PUBLIC_URL`, `FRUS_PDF_URL` and `FRUS_OFFLINE`. Every problem is reported at once. Standalone mode and sign-in are refused until their phases. Beyond SPEC's table:
  - `FRUS_HOST` defaults to 127.0.0.1, as SPEC's Security section asks; the image in S5 sets 0.0.0.0.
  - `FRUS_PORT` defaults to 8080.
  - `FRUS_IMPORT_POLL_SECONDS` defaults to 2, from 0.05 to 3600.
  - `LOG_LEVEL` sets the log level.
- **Import mode.** A watcher looks at `/data/import`. It imports a file once the file has stopped changing between two looks and has reached the size its SQLite header records; `docker compose cp` makes a file visible while it is still copying. The steps:
  1. `copying_export`: the backup API copies the export into `frus.db.new`.
  2. `checking_format`: the tables are present, `user_version` is 4, and the copy is switched to rollback-journal mode.
  3. `checking_versions`: a stamped export must have both index versions at 65 and both FTS schema versions at 4. An unstamped copy must have every `document_revisions.index_version` at 65.
  4. `checking_writing`: an export with notes, summaries or tags is refused, since phase 1 serves the corpus only. So is a stamp that denies writing the file holds.
  5. `checking_integrity`: `quick_check`, then the rank-1 check on both FTS tables, run on the writable copy.
  6. `installing_index`: through `IndexWriter`, `frus.db` becomes `frus.db.prev` and `frus.db.new` becomes `frus.db`.
  7. `opening_index`: the index opens with `immutable=1`.

  Failures are sorted by fault:
  - **The file's fault** (a refusal): it stays where it is and is not tried again until it changes.
  - **The server's fault** (too little disk space, a write error): it is tried again after a minute.

  An installed file is removed from the drop zone. If it cannot be removed, the import report says so, and it is not imported again. An export that is already live, found again after a restart that came between installing it and removing it, is removed rather than re-imported over the rollback copy. A copy that arrives with a non-empty `-wal` beside it is refused: `immutable=1` would ignore the newest data in it.

  The install keeps the old index as `frus.db.prev` through a hard link, then replaces `frus.db` with one atomic `rename`, so `frus.db` exists at every instant.

  Blocking SQLite work runs on Dispatch threads, off Swift's cooperative pool. At start, the server listens before it opens the existing index, so `/healthz` answers at once; meanwhile `/readyz` reports `opening_index`. An index at another version leaves the server not ready, with both versions named. A file still arriving is named in `/readyz`.
- **The five v1 interfaces**, each with its phase 1 implementation:
  1. `IndexWriter`: `LocalIndexWriter`, plus `ReadOnlyIndexWriter` for snapshot mode.
  2. `CorrectionStore`: override rows in `app.db`.
  3. `UserStore`: `SQLiteUserStore`, with numbered migrations. Migration 1 adds `users` and `index_corrections`.
  4. `SessionStore` (in memory), `JobQueue` (in process; imports run as jobs) and `FileStore` (`DataDirectory`).
  5. `/healthz` and `/readyz`.
- **Tests.** Synthetic exports are built from the real v65 export's schema, kept as `Tests/FRUSLightTestSupport/Fixtures/export-v65-schema.sql` (schema only, no rows). The tests cover:
  - every refusal reason;
  - disk space as a server-side problem that is tried again;
  - an undeletable drop file, and an export that is already live;
  - the walk through every import step, checked at `/readyz` through the router;
  - a restart, and the watcher's import, through the application `buildApplication` makes;
  - a clean stop on shutdown;
  - that the supported index version, the FTS schema version and the export's FTS DDL match the pinned submodule.

  One path is covered only by sorting a SQLite failure by its result code: a destination write failing during the copy.

**Results**

| Target | Tests | Linux, arm64 | macOS, native |
| --- | --- | --- | --- |
| SourceNoteKitTests | 292 | Pass | Pass |
| CrossRefKitTests | 10 | Pass | Pass |
| GeneratorKitTests | 7 | Pass | Pass |
| FTS5CheckTests | 3 | Pass | Pass |
| FRUSLightCoreTests | 36 | Pass | Pass |
| FRUSLightServerTests | 8 | Pass | Pass |

**The owner's real export.** The 2.83 GB file, exported on 3 October from build 49, was imported on Linux in a container, with `/data` in a named volume and the file copied in with `docker cp`:
- the server waited for the copy to finish;
- it imported in about 18 seconds: 3 to copy, 15 to check;
- it then served 316,768 documents from 553 volumes, at index version 65.

A restart was ready in 2 seconds with no copy. The import was then repeated with the container on one CPU:
- across 164 `/healthz` requests made during the 15-second integrity check, the slowest took 17 ms;
- SIGTERM stopped the server with exit status 0 in 0.15 seconds.

**Deferred, with the reason**

- Comparing each document's `content_hash` and `body_hash` with its TEI (SPEC's import step 5), and a `content_hash` self-check. Both need `IndexingPipeline` (S6); hashing here would reimplement it (rule 4).
- Moving an export's writing into the user store waits for phase 2, as do the backups that precede each `app.db` migration.
- SPEC rule 7 has the server write corrections into the index, but phase 1 serves it immutable. Corrections are stored as override rows first, and how they reach a served index is decided before phase 3.

**Next: S5.** The image and a Compose smoke test, on the server track. S4, the parity harness, needs no upstream changes and can run too. S1, S3 and S6 wait for upstream pull requests.

## Session 0: the scaffold

3 October 2026 · branch `claude/s0-scaffold`

This session ran on the owner's Mac rather than in a cloud session: macOS 27, Docker Desktop 4.93, `swift:6.4-noble` on arm64. No tool available here opens a cloud session with both repositories selected. CI runs the same build on GitHub's amd64 runner. The shared plan (rev 43) and specification matched their files when the session started.

**Delivered**

- `upstream/FRUS-Explorer`, pinned to `34a5120` (tag `build-49`, index version 65). That commit matches the owner's Mac build and research export.
- `scripts/swift`, which runs SwiftPM in `swift:6.4-noble` plus `libsqlite3-dev`, in a derived image it builds once. `scripts/doctor` checks Docker, the image, the submodule and the container's network.
- `Package.swift`:
  - `CSQLite`;
  - SourceNoteKit, CrossRefKit and GeneratorKit and their tests, from the submodule with upstream's settings;
  - `FTS5Schema`, which is `FTS5Types.swift` alone;
  - the FTS5 check;
  - `FRUSLightServer`, which prints its version.
- `.github/workflows/ci.yml`: build, test (failing on any skipped test) and counts per target.
- `fixtures/tei/`: the three volumes from HistoryAtState/frus `8e5da08`, with `SOURCE` and `SHA256SUMS`. They are byte-identical to the Mac app's copies and to GitHub's.
- `CLAUDE.md`, this log and `.gitignore`.

**Results**

| Target | Tests | Linux, arm64 | macOS, native |
| --- | --- | --- | --- |
| SourceNoteKitTests | 292 | Pass | Pass |
| CrossRefKitTests | 10 | Pass | Pass |
| GeneratorKitTests | 7 | Pass | Pass |
| FTS5CheckTests | 3 | Pass | Pass |

Both builds have no warnings. CI on GitHub's amd64 runner passed with the same counts (run 37146459177); the build took 26 seconds. The FTS5 check builds `frus_documents` with `FTS5Schema.frusDocuments.createTableSQL` over a `document_cache` content table.
- **Prefix stemming:** FTS5's porter tokenizer stems a prefix term as if it were a whole word. So `negoti*` and `negotiating*` match "negotiating", while `negotiat*` stays `negotiat*` and matches nothing; no stored term begins with it.
- **NEAR distance:** a second document holds both words beyond the NEAR distance, so the distance itself is tested.
- **Malformed queries:** a malformed query must throw rather than return no rows.

**Notes for later sessions**

- `scripts/swift` passes proxy variables and a CA bundle only when they are set, and none were set here. S1, the first cloud session, should run `scripts/doctor` first and record whether the container reaches github.com.
- Both scripts add `~/.docker/bin` to `PATH` when `docker` is missing, as on a Mac where Docker Desktop's CLI is not on a non-interactive shell's path.
- In a git worktree, `/src/.git` points outside the container's mount, so git inside the container fails at the repository root. SwiftPM builds don't need it; `scripts/doctor` runs its network check from `/tmp`.
- Rule 3 asks for the session's task to be ticked in `docs/PLAN.md`, but the plan has no per-session checkbox, so nothing was ticked. Changing the plan would also put it out of step with its shared copy. `docs/prep/README.md` now lists this under "Before the S1 prompt".
- After this CI has run, the owner protects `main`: pull requests required, no required approvals, and the `swift` check required.

**Next: S1.** An upstream pull request with Linux guards for TEIHeaderKit, SemanticVectorsKit and FTS5Store. Before writing its prompt, settle the items under "Before the S1 prompt" in `docs/prep/README.md`, and answer the plan's open question on pull requests to `FRUS-Explorer`. `docs/prep/s1-linux-guards.patch` is a starting point.
