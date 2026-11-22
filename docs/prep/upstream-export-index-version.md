# Upstream: the Mac shows the index version an export carries (FRUS-Explorer#1910)

FRUS-Explorer#1948, merged as `9e582653e0fac9a8778e2dbfee170ed4b0067223` on 2026-11-17. It is first in 1.0 (1823), the fourth TestFlight build (the plan of record's decision 137), and then in 1.0 (1861), the App Store submission, built from the same tree. Where it shows, and in what words: on the Mac only, in Settings ▸ System ▸ Data & Recovery, as a line under **Export Research Database…**: *The copy will carry index version 75.* That is the installed version, the one the copy's `research_provenance` stamps as `installed_index_version`. With an older index it reads *The copy will carry index version 74, not this build’s 75.*; while indexing runs, when the button is disabled, *The index is being updated to version 75. You can export it when the update is done.* (or *The index is being updated. You can export it when the update is done.* when the index is already at the build's version); with no version recorded, *The index has no version recorded yet.* After a copy that verified, the line below it reads *Exported 1.45 GB, index version 75.*: its size and the version its own stamp records.

## The web's steps

The server needs nothing, and no pin move is needed for it. Once a build that shows it ships:

1. **`docs/INSTALL.md`** says where the Mac shows the version:
   - in its first list, where a research export comes "from a Mac running a build that matches the server's index version";
   - in Troubleshooting's row for "This export is index version N; this server serves index version M".
2. **COORDINATION §5:** the item "the index version shown beside Export Research Database…" goes from the list of app changes the web edition needs.
3. **Records:** a DEVLOG entry for the docs change.

## Taken

By S12d's pin move to the tag `1.0-release` (`08e8bac8`), the move that brought 1.0 (1861) (the log's entry, Session 12d):
- `docs/INSTALL.md` says where the Mac shows the version, in its first list and in Troubleshooting's row, with the pane's place, Settings ▸ System ▸ Data & Recovery, in the guide's other two steps too.
- COORDINATION §5's item "the index version shown beside Export Research Database…" is closed.
