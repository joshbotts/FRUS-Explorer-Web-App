# Upstream: the graph's timeline lays out at any width (FRUS-Explorer#1893)

FRUS-Explorer#1934, merged as `61cdeaeb`. Below 116 pt the layout now closes the axis's visible range on its leading end, x = 48, and keeps only a tick that falls there, which in practice is none; every node is placed, and from 116 pt every tick is as before.

## The web's steps

1. **The pin move:** move to a `v2` commit at or past `61cdeaeb`, by COORDINATION §5's checklist. Its run fails #1893's half of `CrossReferenceGraphParityTests.theTwoUpstreamIssuesStandAtThisPin` by design: the kit file's range expression has changed.
2. **The route:** `Sources/FRUSLightAPI/CrossReferenceGraph.swift` lays the timeline out at the width asked, without its 116-pt floor. The floor is in the comments naming #1893, near :144, :205, :378 and :383. If the merged fix says a narrower canvas draws no timeline, follow the kit.
3. **Tests:** these expect the kit's layout at the width asked:
   - the narrow-width tests in `Tests/FRUSLightServerTests/CrossReferenceGraphRouteTests.swift`, near :71 and :75;
   - `Tests/FRUSParityTests/CrossReferenceGraphParityTests.swift`, near :145, and #1893's half of `theTwoUpstreamIssuesStandAtThisPin`.
4. **Records:**
   - The README's Known gaps line on the graph's workarounds drops #1893.
   - So does COORDINATION §5's "What the web works around until the app fixes it". If #1892 is fixed too, both lines go.
   - The pin move's DEVLOG entry says so.

## Taken

By S12d's pin move to the tag `1.0-release` (`08e8bac8`), which holds `61cdeaeb` (the log's entry, Session 12d), steps 1 to 4:
- The route lays the timeline out at the width asked, 1 to 4,096 points, with no floor (`narrowestTimeline` is gone).
- `CrossReferenceGraphRouteTests.aTimelineIsLaidOutAtTheWidthAsked` lays one out at 1, 50, 115, 116, 117 and 900 points, every node placed, and within the canvas from 116.
- `CrossReferenceGraphParityTests` calls the kit at the width asked, and `theTwoUpstreamFixesHoldAtThisPin` holds the API's timeline at 50 points to the kit's for the first 60 fixture documents.
- The README's Known gaps, COORDINATION §5 and SPEC's graph lines no longer name the floor.
