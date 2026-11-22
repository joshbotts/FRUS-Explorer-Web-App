# Upstream: boundary tests for every shared kit (FRUS-Explorer#1911)

FRUS-Explorer#1969, merged as `5f0a07f342cb86908ef9d587ef0ac18e27685147` on 2026-11-22. The test:
- **Its name and target:** `SharedKitsBoundaryTests`, in `FRUSExplorerTests/FRUSCoreKitBoundaryTests.swift` beside `FRUSCoreKitBoundaryTests`, whose scanner it uses. It is in the app's unit target (Xcode) alone, as that suite is, not a package suite: the scanner blanks comments and literals with `CodingStandardsAuditTests`' masking, which only the unit target compiles.
- **The kits it covers:** FTS5Store, SourceNoteKit, CrossRefKit, GeneratorKit, TEIHeaderKit, SemanticVectorsKit, WordCloudKit and ManifestGeneratorCore, each with its suites' folder. A test reads the app's `CLAUDE.md` list of shared code, so a kit added there fails the suite until it has a row.
- **Its rules:** a kit's file imports Foundation, a module behind the `canImport` that selects it, or one its row allows anywhere with the reason. No file reads `Bundle.main` (a `Bundle = .main` default and a `bundle: .main` argument included), `UserDefaults` or the Keychain. No file names a declaration at the top level of a file under `FRUSExplorer/`, nor, in a suite, under `FRUSExplorerTests/`. A suite's lines that only Xcode compiles are exempt, as in FRUSCoreKit's suite.
- **The allowances its rows name**, each behind its guard:
  - SQLite3, or `CSQLite` in its `#else`, and OSLog (FTS5Store);
  - FoundationXML (TEIHeaderKit);
  - CryptoKit, or swift-crypto's `Crypto` in its `#else` (SemanticVectorsKit, WordCloudKit);
  - NaturalLanguage and `os` inside `#if canImport(NaturalLanguage)` (WordCloudKit, #1900);
  - FoundationNetworking (ManifestGeneratorCore).

  Anywhere: ManifestGeneratorCore's TEIHeaderKit, its package dependency, which no app target compiles beside it. Each suites' folder may import `Testing` and its kit.
- **FRUSCoreKit's own gate** reads three things more, with the same scanner: an access-level import (`public import`, SE-0409), a `bundle: .main` argument, and the Keychain (`SecItem…`, `SecKeychain…`, `kSec…`).
- **What it cannot see** (its doc comment): a file of one kit the app compiles naming a declaration of another kit the app compiles that its package target does not depend on, since Xcode builds them as one module. The package's build catches that, as the web's Linux build at a pin does.

## The web's steps

1. **The pin move:** nothing to run. `SharedKitsBoundaryTests` is not a package suite, so the web's swift job neither compiles nor runs it, and CI's skip allow-list needs nothing. #1969 changed no folder the golden files' digest covers. The move that carries it comes after S12d's, which goes to the tag `1.0-release` (`08e8bac8`) and no further: to a `v2` commit at or past `4556c4d5`, with this batch's other two pull requests (#1967 and #1968).
2. **COORDINATION:** the sentence "Since #1569, a test in the app's normal Xcode run checks rules 1 and 2 for `FRUSCoreKit/`" (the division of labour) and §4's "The boundary test checks rules 1 and 2 for `FRUSCoreKit/`" name every kit: since #1969 the same run checks rules 1 and 2 for all the shared code. §5's item "boundary tests for the other kits" goes.
3. **The app's `CLAUDE.md`:** done in #1969. A paragraph after FRUSCoreKit's gate names `SharedKitsBoundaryTests` and its rules, and says that a kit added to the "Web edition" section's shared code needs its row there. The "Web edition" section needs no change.
4. **Records:** the pin move's DEVLOG entry says so.

## Taken

By the pin move to `4556c4d5`, `v2`'s head (the log's entry, "Session 24f, second follow-up", which says so), steps 1, 2 and 4: nothing ran for it. COORDINATION's sentence in the division of labour and §4's opening name every kit, §3's boundary test names `SharedKitsBoundaryTests` beside `FRUSCoreKitBoundaryTests`, and §5's item "boundary tests for the other kits" is gone.
