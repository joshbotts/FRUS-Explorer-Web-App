# Upstream: a graph at two or three hops keeps its undownloaded citers (FRUS-Explorer#1892)

FRUS-Explorer#1934, merged as `61cdeaeb`.

## The web's steps

1. **The pin move:** move to a `v2` commit at or past `61cdeaeb`, by COORDINATION §5's checklist. Its run fails #1892's half of `CrossReferenceGraphParityTests.theTwoUpstreamIssuesStandAtThisPin` by design: that is the sign the workaround can go.
2. **The route:** `Sources/FRUSLightAPI/CrossReferenceGraph.swift` takes the banner's volumes from the degree-1 graph. That is the read near :291, with the doc comment at :49 and the file's header at :20, each naming #1892.
   - Read `undownloadedCitingVolumeIds` from the graph at the degree asked.
   - Drop the degree-1 read.
3. **Tests:**
   - Drop #1892's half of `theTwoUpstreamIssuesStandAtThisPin`, from about :372 to :384, and the store-file check near :399–401. Its #1893 half stays until that issue is fixed.
   - The banner's volumes at two and three hops come from the kit's own graph in the route and parity tests.
4. **Records:**
   - The README's Known gaps line "The cross-reference graph works around two of the app's behaviours…" drops #1892.
   - So does COORDINATION §5's "What the web works around until the app fixes it".
   - The pin move's DEVLOG entry says so.

## Taken

By S12d's pin move to the tag `1.0-release` (`08e8bac8`), which holds `61cdeaeb` (the log's entry, Session 12d), steps 1 to 4:
- `Sources/FRUSLightAPI/CrossReferenceGraph.swift` reads the loaded graph's `undownloadedCitingVolumeIds` at any degree, as the app's view model does, and reads no degree-1 graph beside it.
- `CrossReferenceGraphParityTests` builds the kit's answer from the loaded graph alone, and `theTwoUpstreamIssuesStandAtThisPin` is `theTwoUpstreamFixesHoldAtThisPin`, which holds each document's volumes at two and three hops to its one-hop graph's.
- The README's Known gaps, COORDINATION §5 and SPEC's graph lines no longer name the workaround.
