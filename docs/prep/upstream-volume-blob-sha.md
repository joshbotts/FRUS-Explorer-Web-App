# Upstream: an export names the file each volume was indexed from (FRUS-Explorer#1909)

FRUS-Explorer#1948, merged as `9e582653e0fac9a8778e2dbfee170ed4b0067223` on 2026-11-17.
- The index version: 75 (it was 74). Exports from 1.0 (1823) and 1.0 (1861) carry 75, which the published server refuses until this pin move ships (COORDINATION §4). The version's re-index fills the record for every volume of a library once, at its first launch of a build at 75.
- The record: two columns on the per-volume row the index already keeps, `volume_structures`; no table is added or removed. `file_blob_sha1 TEXT` is the git blob SHA-1 of the bytes the volume's last store pass parsed (`VolumeUpdateChecker.gitBlobSHA1(for:)` of them: 40 lowercase hex digits, the hash GitHub reports for the file), and `file_size_bytes INTEGER` is their length. The pass reads the file once, hashes those bytes and parses the same bytes, and writes both columns with the row, last, so a pass cut short leaves no record, re-indexing replaces it and removing the volume removes it. A volume indexed before 75 has `NULL` in both, and an index from before 75 has neither column. The kit reads it with `IndexingPipeline.indexedVolumeFiles()` and `indexedVolumeFile(forVolumeId:)` (`IndexedVolumeFile`: `volumeId`, `blobSHA1`, `sizeBytes`), public and nonisolated, through the read-write open and both read-only ones; an index from before 75 opened read-only answers with none. Measured on a full index of the 553 catalogue volumes at corpus `6170e4b32`: every record equals the blob SHA-1 and size `git ls-tree -l 6170e4b32 volumes/` gives for its file.

## The web's steps

1. **The pin move,** by COORDINATION §5's checklist:
   - a new `Tests/FRUSLightTestSupport/Fixtures/export-v75-schema.sql`, from a real export by the pinned build (the owner is asked for one);
   - `Tests/FRUSParity/IndexSchema.swift`'s table list;
   - `Sources/FRUSLightCore/Compatibility.swift`, and the index version in `docs/INSTALL.md`, if the version moved;
   - golden files from a new three-volume export.
2. **Import mode's step 5** (`Sources/FRUSLightCore/TEIChanges.swift`):
   - Hash each mounted volume's file with the kit's `VolumeUpdateChecker.gitBlobSHA1(for:)` first.
   - Give the revision-hash comparison only the volumes whose file is not the one the export indexed.
   - An export without the record compares every volume, as now.
3. **Measure,** as S21f's step 5 follow-up did: `fixtures/sample`'s 24 volumes took 11.68 s unchanged before.
4. **Records:**
   - the README's Known gaps line on Import mode's first comparison;
   - COORDINATION §5's "What the library's rows leave upstream", whose first item this closes;
   - a DEVLOG follow-up entry above Session 21f's.

## Taken

By S12d's pin move to the tag `1.0-release` (`08e8bac8`), which holds `9e582653` (the log's entry, Session 12d), step 1:
- `Compatibility.swift` and the install guide name index version 75.
- `IndexSchema.swift`'s `volume_structures` lists the two columns, and its set hash carries each volume's file record. The summary's schema digest reads each statement's text with its layout set aside, since the owner's golden library gains the columns by `ALTER TABLE`, which appends them to the stored statement, and a fixture index made at 75 by `CREATE TABLE`.
- The schema fixture and the golden files come from the owner's 1861 three-volume export of 22 November, whose `volume_structures` holds a 40-digit `file_blob_sha1` and a `file_size_bytes` for each of its three volumes. The full export of that day is not the fixture's source: its library's upgrades give two tables' columns another order (the log's entry).

Steps 2 to 4, Import mode's step 5 hashing each mounted file first, its measure and their records, are a follow-up of their own.
