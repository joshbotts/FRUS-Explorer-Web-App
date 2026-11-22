# Upstream: Import from JSON on every platform, with the rules in the kit (FRUS-Explorer#1915)

FRUS-Explorer#1950 (the kit's rules) and FRUS-Explorer#1951 (the screen), merged as `b1f98323` and `fa9ae409`.
- The kit's API: `ResearchImportPlan(file:library:)` over `ResearchImportFile(data:)` and `ResearchLibrarySnapshot`, applied through `Item.written(over:)` (`FRUSCoreKit/Export/ResearchImportPlan.swift`). A host writes an addition's `Item.record`, a replacement's `Item.written(over:)` of its own copy, and nothing for a record kept. The plan's `Report` is what a screen shows before anything is written.
- The screen: Settings ▸ System ▸ Data & Recovery ▸ Import from JSON…, first in 1.0 (1823).
- Checked on the Mac with an export the web's own code wrote (`main` at `b31da01`; format 7 with its `frusExplorerLight` key): 15 records added, the web's note kept its formatting, and a second import planned nothing.

## The web's steps

1. **The pin move:** move to a `v2` commit at or past `b1f98323`, by COORDINATION §5's checklist, so that the server compiles the kit's rules. (`fa9ae409`, the screen, changed no shared code.)
2. **The import:** the web's `Sources/FRUSLightAPI/MacImport.swift` and `Sources/FRUSLightCore/UserResearchImport.swift` make the decisions the kit now makes:
   - a newer copy wins;
   - only the fields the file's version carries are written;
   - an older file's defaults.
   Take them from the kit's plan (CLAUDE.md rule 4), and keep the SQL that applies them the web's own. The import report's counts come from the kit's report, with the web's own lines beside it (formatting kept, the curator's corrections).
   - **The text rule the web's import lacks.** In the kit, a field that describes a text does not outlive the text:
     - a file before version 7 that replaces a note's text leaves the note plain (`richText` nil), as the app's note editor leaves a note whose text it replaces wholesale;
     - a file before version 5 that replaces a summary's text leaves it AI-generated;
     - where the file's text is the library's, the library's formatting and authorship stay.

     The web's import keeps both whatever the text. Taking `Item.written(over:)` brings the rule, which the owner kept on 2026-11-17. The web's "formatting kept" line then holds only where the text is unchanged. The kit's report does not count the other cases, since only a write sees them. The app counts them as it writes (a note whose copy had formatting and whose written record has none; a summary not AI-generated that becomes so) and shows them in its done line.
   - **Where the kit's plan differs from the web's importer** (from #1950):
     - a summary from a file before version 5 is added as AI-generated, where the web writes none; both readers read the two alike;
     - the report counts as inert only the entries the import adds, and names as unlinked only the collections it writes; the web counts the file's;
     - the corrections are always planned; the web's curator rule stays the web's own line beside the kit's report.
3. **A round trip:** a test that the web's export of a fixture user (`Sources/FRUSLightAPI/ResearchExport.swift`), planned by the kit into an empty snapshot, gives back every record.
4. **Docs:**
   - `docs/INSTALL.md` says how research goes from the web back to the app: Export on the web, then Settings ▸ System ▸ Data & Recovery ▸ Import from JSON… on Mac, iPhone or iPad.
   - SPEC's export section and the README's What works today say the same.
   - COORDINATION §5's item "optionally, a JSON importer, so data made on the web can return to the Mac" closes.
5. **Records:** a DEVLOG follow-up entry above Session 16c's, the web's import.

## Taken

By S12d's pin move to the tag `1.0-release` (`08e8bac8`), which holds `b1f98323` (the log's entry, Session 12d), step 1: the server compiles `Export/ResearchImportPlan.swift` and calls none of it yet.

Steps 2 to 5, the web's import taking the kit's plan with its text rule, the round trip, the docs and their record, are a follow-up of their own.
