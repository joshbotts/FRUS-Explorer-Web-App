# Upstream: the graph's timeline eligibility reads the built nodes (FRUS-Explorer#1914)

FRUS-Explorer#1934, merged as `61cdeaeb`.

## The web's steps

**Nothing changes in the server.** S23e's route already asks `isTimelineEligible` over the built nodes each time (`Sources/FRUSLightAPI/CrossReferenceGraph.swift`), as the fixed app does.

**At the pin move that takes it:**
- check `CrossReferenceGraphParityTests`, which mirror the app's eligibility;
- if a record names this difference between the app and the web, mark it closed.

**Records:** the pin move's DEVLOG entry says so.

## Taken

By S12d's pin move to the tag `1.0-release` (`08e8bac8`), which holds `61cdeaeb` (the log's entry, Session 12d):
- `CrossReferenceGraphParityTests.theMirrorsAreTheApps` holds the app's new line, `isTimelineEligible(… nodes: baseDisplayNodes.isEmpty ? displayNodes : baseDisplayNodes)`.
- The route's comment, which named the difference (the app's later layouts asked it of the clustered nodes they drew), now says the app asks it of the built nodes, as the server does.
