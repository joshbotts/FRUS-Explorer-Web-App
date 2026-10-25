// Envelopes the kit writes, for the import's tests (PLAN's S16c): every model type, made with the kit's
// own records and written by its encoder, at format version 7 and at 6, which a Mac at build 50
// writes; and the browser suite's, fixtures/import/research-export.json, whose highlights are placed
// over the fixture TEI's own text, so the reader draws them where the Mac would.

import FRUSCoreKit
import FRUSRichText
import Foundation

public enum ImportFixtures {
    /// The browser suite's export, written by `frus-parity import-fixture` and held to it by
    /// FRUSParityTests.
    public static let browserSuitePath = "fixtures/import/research-export.json"

    /// The top-level keys a file before version 7 lacks, as build 50's encoder wrote none of them.
    public static let version7Keys: Set<String> = [
        "savedSearches", "workingCorpora", "customVolumeScopes", "classificationOverrides", "personClusterOverrides",
        "annotationReviews", "projectLeads", "syncedPreferences",
    ]

    /// An id of the import's fixtures, `5E16C000-…-n` in hex.
    public static func id(_ number: Int) -> UUID {
        UUID(uuidString: "5E16C000-0000-4000-8000-" + String(format: "%012X", number))!
    }

    static func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    /// The app's headnote draft prompt.
    static let headnotePrompt = UUID(uuidString: "0EAD0000-0000-4000-8000-000000000001")!
    /// A standard prompt's id on the Mac that wrote the file, which an export never carries.
    static let standardPrompt = UUID(uuidString: "AB000000-0000-4000-8000-000000000001")!

    /// The envelope's file as the Mac writes one at its version: the kit's encoder, and before
    /// version 7 without the keys build 50's encoder did not have.
    public static func file(_ envelope: ResearchDataEnvelope) throws -> Data {
        let data = try envelope.jsonData()
        guard envelope.formatVersion < 7 else { return data }
        var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        for key in version7Keys { object[key] = nil }
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    /// Several records of every type a file of `formatVersion`, 6 or 7, carries, and in each the
    /// cases an import must keep: dangling ids, RTF the codec reads and RTF it keeps, a version-6
    /// entry with no document, a smart collection whose saved search the file holds and one whose it
    /// does not, a headnote draft, each authorship, a structured prompt, two sets of synced
    /// settings, and both corrections.
    public static func everyType(formatVersion version: Int) -> ResearchDataEnvelope {
        let v7 = version >= 7
        let formatted = RTFWriter.write([RichTextRun(text: "A "), RichTextRun(text: "bold", bold: true),
                                         RichTextRun(text: " note.")])
        // RTF whose text is not the note's, as another device's edit can leave one: kept as it came.
        let other = Data(#"{\rtf1\ansi\ansicpg1252\cocoartf2868 {\fonttbl\f0\fnil Helvetica;}\f0 Another text}"#.utf8)
        let notes = [
            ResearchNoteExport(id: id(1), documentId: "d3", volumeId: "frus1961-63v06", bodyText: "A plain note on d3.",
                               projectIds: [id(40)], userTagIds: [id(20)], selectedSummaryIds: [id(70)],
                               linkedHighlightIds: [id(10)], createdAt: date("2026-03-01T10:00:00Z"),
                               lastModified: date("2026-03-02T10:00:00Z")),
            ResearchNoteExport(id: id(2), documentId: "d4", volumeId: "frus1961-63v06", bodyText: "A bold note.",
                               projectIds: [], userTagIds: [id(20), id(21)], selectedSummaryIds: [], linkedHighlightIds: [],
                               createdAt: date("2026-03-03T10:00:00Z"), lastModified: date("2026-03-03T11:00:00Z"),
                               richText: v7 ? Data(formatted) : nil),
            // Ids that name what the file does not hold, as the Mac keeps after a delete elsewhere.
            ResearchNoteExport(id: id(3), documentId: "d4", volumeId: "frus1961-63v06", bodyText: "A note kept as it came.",
                               projectIds: [id(49)], userTagIds: [id(29)], selectedSummaryIds: [id(79)], linkedHighlightIds: [],
                               createdAt: nil, lastModified: nil, richText: v7 ? other : nil),
        ]
        let highlights = [
            DocumentHighlightExport(id: id(10), volumeId: "frus1961-63v06", documentId: "d3", startOffset: 4, endOffset: 19,
                                    colorTag: "yellow", noteId: id(1), selectedText: "Kept verbatim",
                                    renderingVersion: "0123456789abcdef", createdAt: date("2026-03-01T09:00:00Z")),
            DocumentHighlightExport(id: id(11), volumeId: "frus1961-63v06", documentId: "d3", startOffset: 30, endOffset: 80,
                                    colorTag: "pink", selectedText: "First part.\n\nSecond part.",
                                    renderingVersion: "fedcba9876543210", createdAt: nil),
            DocumentHighlightExport(id: id(12), volumeId: "frus1894Nicaragua", documentId: "d2", startOffset: 0, endOffset: 7,
                                    colorTag: "green", selectedText: "Managua", renderingVersion: "0123456789abcdef",
                                    createdAt: date("2026-03-05T09:00:00Z")),
        ]
        let tags = [
            UserTagExport(id: id(20), name: "Cuba", createdAt: date("2026-02-01T00:00:00Z"), lastModified: date("2026-02-02T00:00:00Z")),
            UserTagExport(id: id(21), name: "Primary source", createdAt: nil, lastModified: nil),
        ]
        let assignments = [
            DocumentTagAssignmentExport(id: id(30), volumeId: "frus1961-63v06", documentId: "d3", tagId: id(20),
                                        createdAt: date("2026-02-03T00:00:00Z")),
            DocumentTagAssignmentExport(id: id(31), volumeId: "frus1961-63v06", documentId: "d4", tagId: id(21)),
            DocumentTagAssignmentExport(id: id(32), volumeId: "frus1894Nicaragua", documentId: "d2", tagId: id(29),
                                        createdAt: date("2026-02-04T00:00:00Z")),
        ]
        let projects = [
            ProjectExport(id: id(40), name: "Bay of Pigs review", researchQuestion: "What did the planners expect?",
                          defaultDateRangeStart: date("1961-01-01T00:00:00Z"), defaultDateRangeEnd: date("1961-12-31T00:00:00Z"),
                          defaultSubjectTagIds: ["cuba", "covert-action"], defaultCountryTagIds: ["cu"],
                          createdAt: date("2026-01-10T00:00:00Z"), lastModified: date("2026-01-11T00:00:00Z"),
                          defaultUserTagIds: v7 ? [id(20)] : nil, leadAxisWeights: v7 ? #"{"citation":0.5}"# : nil),
            ProjectExport(id: id(41), name: "Nicaragua, 1894", defaultSubjectTagIds: [], defaultCountryTagIds: [],
                          defaultUserTagIds: v7 ? [] : nil),
        ]
        var entries = [
            CollectionEntryExport(id: id(51), documentId: "d3", volumeId: "frus1961-63v06", sortOrder: 0, researchNoteId: id(1),
                                  selectedNoteIds: [id(1)], createdAt: date("2026-04-01T00:00:00Z"),
                                  lastModified: date("2026-04-01T00:00:00Z")),
        ]
        if v7 {
            entries[0].kind = "document"
            entries[0].level = 1
            entries[0].titleOverride = "The planners' memorandum"
            entries[0].bodyDepthOverride = "summaryOnly"
            entries[0].applyHighlightsOverride = true
            entries[0].includeNotesOverride = false
            entries[0].includeSourceNoteOverride = true
            entries[0].includeFootnotesOverride = false
            entries[0].summaryPromptIdOverride = id(80)
            entries[0].selectedHighlightIds = [id(10)]
            entries[0].includeRelatedDocuments = true
            entries[0].includeHeadnote = true
            entries[0].headnoteSummaryId = id(73)
            entries += [
                CollectionEntryExport(id: id(52), documentId: "", volumeId: "", sortOrder: 1, selectedNoteIds: [],
                                      lastModified: date("2026-04-02T00:00:00Z"), kind: "heading", level: 2,
                                      text: "Planning", selectedHighlightIds: []),
                CollectionEntryExport(id: id(53), documentId: "", volumeId: "", sortOrder: 2, selectedNoteIds: [],
                                      kind: "prose", level: 1, text: "A bold note.", richText: Data(formatted),
                                      selectedHighlightIds: []),
                CollectionEntryExport(id: id(54), documentId: "d3", volumeId: "frus1961-63v06", sortOrder: 3, selectedNoteIds: [],
                                      kind: "excerpt", level: 1, text: "Kept verbatim", excerptStart: 4, excerptEnd: 19,
                                      excerptRenderingVersion: "0123456789abcdef", excerptColorTag: "yellow",
                                      selectedHighlightIds: []),
                CollectionEntryExport(id: id(55), documentId: "", volumeId: "", sortOrder: 4, selectedNoteIds: [],
                                      kind: "generated", level: 1, generatedBlockType: "bibliography", selectedHighlightIds: []),
            ]
        } else {
            // What version 6 writes for a heading, a prose block or an apparatus block: no document.
            entries.append(CollectionEntryExport(id: id(52), documentId: "", volumeId: "", sortOrder: 1, selectedNoteIds: [],
                                                 lastModified: date("2026-04-02T00:00:00Z")))
        }
        var collections = [
            CollectionExport(id: id(50), name: "Briefing book", note: "For the seminar", projectIds: [id(40)], entries: entries,
                             createdAt: date("2026-04-01T00:00:00Z"), lastModified: date("2026-04-03T00:00:00Z")),
            // Smart: its saved search is in a file of version 7, which carries saved searches.
            CollectionExport(id: id(56), name: "Every covert action", projectIds: [], savedSearchId: id(90), entries: [],
                             createdAt: date("2026-04-04T00:00:00Z"), lastModified: date("2026-04-04T00:00:00Z")),
            // Smart, whose saved search the file lacks at any version.
            CollectionExport(id: id(57), name: "A deleted search's", projectIds: [], savedSearchId: id(99), entries: [],
                             createdAt: date("2026-04-05T00:00:00Z"), lastModified: date("2026-04-05T00:00:00Z")),
        ]
        if v7 {
            collections[0].subtitle = "The 1961 planning"
            collections[0].authorLine = "A researcher"
            collections[0].introductionText = "A bold note."
            collections[0].introductionRichText = Data(formatted)
            collections[0].includeColophon = true
            collections[0].includeProjectProvenance = true
            collections[0].includeMethodAppendix = false
            collections[0].defaultBodyDepth = "summaryOnly"
            collections[0].footnoteStyle = "sourceNoteOnly"
            collections[0].includeFootnotes = false
            collections[0].includeSourceNote = true
            collections[0].tocStyle = "headerAndDateline"
            collections[0].applyHighlights = true
            collections[0].includeNotes = false
            collections[0].includeWordCloud = true
            collections[0].defaultIncludeHeadnote = true
            collections[0].summaryPromptId = id(80)
            for index in 1..<collections.count {
                collections[index].includeColophon = false
                collections[index].includeProjectProvenance = false
                collections[index].includeMethodAppendix = false
                collections[index].defaultBodyDepth = "full"
                collections[index].footnoteStyle = "all"
                collections[index].tocStyle = "citation"
                collections[index].applyHighlights = false
                collections[index].includeNotes = true
                collections[index].includeWordCloud = false
                collections[index].defaultIncludeHeadnote = false
            }
        }
        let prompts = [
            SummarizationPromptExport(id: id(80), name: "Cold War brief", promptText: "Summarize {{DOCUMENT}} for a briefing.",
                                      responseFormat: .general, createdAt: date("2026-01-05T00:00:00Z"),
                                      lastModified: date("2026-01-06T00:00:00Z")),
            SummarizationPromptExport(id: id(81), name: "Who and what", promptText: "List who and what. {{DOCUMENT}}",
                                      responseFormat: .structured(schema: StructuredSummarySchema(fields: [
                                          .init(name: "Who", description: "The people the document names"),
                                          .init(name: "What", description: "What they decided"),
                                      ])),
                                      schema: StructuredSummarySchema(fields: [
                                          .init(name: "Who", description: "The people the document names"),
                                          .init(name: "What", description: "What they decided"),
                                      ]), createdAt: nil, lastModified: nil),
        ]
        let summaries = [
            GeneratedSummaryExport(id: id(70), documentId: "d3", volumeId: "frus1961-63v06", promptId: id(80),
                                   responseText: "An AI summary of d3.", responseFormat: .general, wasChunked: false, projectId: id(40),
                                   createdAt: date("2026-05-01T00:00:00Z"), lastModified: date("2026-05-01T00:00:00Z"),
                                   authorship: .aiGenerated, isHeadnoteDraft: v7 ? false : nil),
            GeneratedSummaryExport(id: id(71), documentId: "d3", volumeId: "frus1961-63v06", promptId: standardPrompt,
                                   responseText: "An AI summary, edited.", responseFormat: .general, wasChunked: true,
                                   createdAt: date("2026-05-02T00:00:00Z"), lastModified: date("2026-05-03T00:00:00Z"),
                                   authorship: .aiEdited, isHeadnoteDraft: v7 ? false : nil),
            GeneratedSummaryExport(id: id(72), documentId: "d4", volumeId: "frus1961-63v06", promptId: id(81),
                                   responseText: #"{"Who":"The planners","What":"To proceed"}"#,
                                   responseFormat: .structured(schema: StructuredSummarySchema(fields: [
                                       .init(name: "Who", description: "The people the document names"),
                                       .init(name: "What", description: "What they decided"),
                                   ])), wasChunked: false, createdAt: date("2026-05-04T00:00:00Z"),
                                   lastModified: date("2026-05-04T00:00:00Z"), authorship: .userWritten,
                                   isHeadnoteDraft: v7 ? false : nil),
            // A collection's headnote draft: in a file before 7, known only by its prompt.
            GeneratedSummaryExport(id: id(73), documentId: "d3", volumeId: "frus1961-63v06", promptId: headnotePrompt,
                                   responseText: "A headnote, private to the collection.", responseFormat: .general,
                                   wasChunked: false, createdAt: date("2026-05-05T00:00:00Z"),
                                   lastModified: date("2026-05-05T00:00:00Z"), authorship: .userWritten,
                                   isHeadnoteDraft: v7 ? true : nil),
        ]
        let reading = [
            ReadingHistoryEntryExport(id: id(100), documentId: "d3", volumeId: "frus1961-63v06", displayTitle: "3. Memorandum",
                                      projectId: id(40), accessedAt: date("2026-06-01T00:00:00Z")),
            ReadingHistoryEntryExport(id: id(101), documentId: "d2", volumeId: "frus1894Nicaragua"),
        ]
        let searches = [
            SearchHistoryEntryExport(id: id(110), queryText: "Zapata", resultCount: 12, projectId: id(40),
                                     executedAt: date("2026-06-02T00:00:00Z"), loadedCount: 12, matchCount: 12, fetchLimit: 7_500,
                                     indexedVolumeCount: 3, scopeSignature: "all", appliedCorpusId: id(120),
                                     renderedExpression: "\"zapata\""),
            SearchHistoryEntryExport(id: id(111), queryText: "nothing at all", resultCount: 0, executedAt: date("2026-06-03T00:00:00Z")),
        ]
        let exports = [
            ExportHistoryEntryExport(id: id(115), format: "zotero-api", documentCount: 4, collectionName: "Briefing book",
                                     projectId: id(40), exportedAt: date("2026-06-04T00:00:00Z")),
        ]
        let plans = [
            ArchiveVisitPlanExport(
                id: id(130), name: "College Park", inquiryText: "The Zapata files", projectIds: [id(40)],
                tiers: [ArchiveVisitTier(id: id(133), label: "First morning", order: 0), ArchiveVisitTier(id: id(134), order: 1)],
                deliverables: ArchiveVisitDeliverables(includeLinks: false, includeTargets: true, includeInquiry: false,
                                                       includeCitationCrib: true),
                documents: [
                    ArchiveVisitDocumentExport(id: id(131), documentKey: "frus1961-63v06/d3", includeSource: true,
                                               includeExternalRefs: false, createdAt: date("2026-06-05T00:00:00Z"),
                                               lastModified: date("2026-06-05T00:00:00Z")),
                    ArchiveVisitDocumentExport(id: id(135), documentKey: "frus1961-63v06/d4", includeSource: false,
                                               includeExternalRefs: true),
                ],
                targets: [
                    ArchiveVisitTargetExport(id: id(132), targetKey: "lot|61D21", tierId: id(133), included: true,
                                             userNote: "Box 4", createdAt: date("2026-06-05T00:00:00Z"),
                                             lastModified: date("2026-06-06T00:00:00Z")),
                    // An orphan: a stored target whose key no longer derives, still the researcher's.
                    ArchiveVisitTargetExport(id: id(136), targetKey: "decimal|737.00/1-161", included: false),
                ],
                createdAt: date("2026-06-05T00:00:00Z"), lastModified: date("2026-06-06T00:00:00Z")),
        ]

        var envelope = ResearchDataEnvelope(
            formatVersion: version, exportedAt: date("2026-10-24T20:00:00Z"), exportedForProjectName: "Bay of Pigs review",
            exportedForProjectResearchQuestion: "What did the planners expect?", notes: notes, tags: tags,
            tagAssignments: assignments, highlights: highlights, collections: collections, prompts: prompts, projects: projects,
            summaries: summaries, readingHistory: reading, searchHistory: searches, exportHistory: exports, archiveVisits: plans)
        guard v7 else { return envelope }
        envelope.savedSearches = [
            SavedSearchExport(id: id(90), name: "Covert action, 1961",
                              parameters: SearchParameters(keywords: "covert action", phrase: "Zapata plan", booleanMode: .or,
                                                           excludedTerms: ["Laos", "Berlin"], prefixWildcard: "guer",
                                                           dateRange: DateRange(earliest: "1961-01-01", latest: "1961-12-31"),
                                                           subjectTagIds: ["cuba"], userTagIds: [id(20).uuidString],
                                                           volumeIds: ["frus1961-63v06"], includeSummaries: false,
                                                           projectId: id(40), documentTypeFilter: .documentsOnly, personRef: "p_KNS2",
                                                           includeFrontMatter: false),
                              lastRunAt: date("2026-06-07T00:00:00Z"), matchCountAtLastRun: 42, indexedVolumeCountAtLastRun: 3,
                              createdAt: date("2026-06-01T00:00:00Z"), lastModified: date("2026-06-07T00:00:00Z")),
            SavedSearchExport(id: id(91), name: "Never run again", parameters: SearchParameters(keywords: "Managua"),
                              createdAt: date("2026-06-08T00:00:00Z"), lastModified: nil),
        ]
        envelope.workingCorpora = [
            WorkingCorpusExport(id: id(120), name: "The planning papers", documentKeys: ["frus1961-63v06/d3", "frus1961-63v06/d4"],
                                capturedAt: date("2026-06-09T00:00:00Z"), sourceQuery: "Zapata", sourceDescription: "From Search",
                                indexedVolumeCountAtCapture: 3, wasTruncatedAtCapture: false, totalMatchCountAtCapture: 2,
                                createdAt: date("2026-06-09T00:00:00Z"), lastModified: date("2026-06-09T00:00:00Z")),
        ]
        envelope.customVolumeScopes = [
            CustomVolumeScopeExport(id: id(140), name: "Kennedy's volumes", volumeIds: ["frus1961-63v06"],
                                    createdAt: date("2026-06-10T00:00:00Z"), lastModified: date("2026-06-10T00:00:00Z")),
        ]
        envelope.classificationOverrides = [
            DocumentClassificationOverrideExport(id: id(150), volumeId: "frus1961-63v06", documentId: "d4", isEditorialNote: true,
                                                 parsedIsEditorialNote: false, createdAt: date("2026-06-11T00:00:00Z")),
        ]
        envelope.personClusterOverrides = [
            PersonClusterOverrideExport(id: id(160), kind: "merge", volumeIdA: "frus1961-63v06", refA: "p_KNS2",
                                        volumeIdB: "frus1961-63v06", refB: "p_KJF1", createdAt: date("2026-06-12T00:00:00Z")),
            PersonClusterOverrideExport(id: id(161), kind: "split", volumeIdA: "frus1894Nicaragua", refA: "p_ZJ1"),
        ]
        envelope.annotationReviews = [
            AnnotationReviewExport(id: id(170), annotationType: "document", volumeId: "frus1961-63v06", documentId: "d3",
                                   contentHash: "a1b2c3d4", changeKind: "corrected", reviewedAt: date("2026-06-13T00:00:00Z")),
        ]
        envelope.projectLeads = [
            ProjectLeadEntryExport(id: id(180), projectId: id(40), volumeId: "frus1961-63v06", documentId: "d5", aggregateScore: 0.75,
                                   contributingSeedKeys: ["frus1961-63v06/d3"], header: "5. Telegram", documentNumber: "5",
                                   isEditorialNote: false, firstSurfacedAt: date("2026-06-14T00:00:00Z"),
                                   lastComputedAt: date("2026-06-15T00:00:00Z"), dismissed: true),
        ]
        // Two sets, as a second device's before iCloud merges them: the app reads the earliest.
        envelope.syncedPreferences = [
            preferences(createdAt: "2026-01-01T00:00:00Z", style: "chicago"),
            preferences(createdAt: "2026-02-01T00:00:00Z", style: "turabian"),
        ]
        return envelope
    }

    static func preferences(createdAt: String, style: String) -> SyncedPreferencesExport {
        SyncedPreferencesExport(createdAt: date(createdAt), updatedAt: date("2026-06-16T00:00:00Z"), wcMinLength: 4, wcMinCount: 2,
                                wcFoldPlurals: true, wcFilterMarkings: false, wcExcludeBoilerplate: true,
                                wcGlobalStopwordsJSON: #"["telegram"]"#, wcLensStopwordsJSON: "{}", citationStyleRaw: style,
                                defaultDocumentModeRaw: "reader", researchLoggingEnabled: false,
                                listOrderJSON: #"{"tags":[]}"#)
    }

    // MARK: The browser suite's

    /// The browser suite's export (web/e2e/import.spec.ts): format version 7 with a record of every
    /// type, on documents of frus1961-63v06 no other spec opens, d3 to d5. Its notes are in two
    /// projects and none, for All Notes' project filter; d3's summaries are an AI summary of one of
    /// the researcher's prompts, an edited one of a standard prompt, which the file does not name, an
    /// imported one of their own and a headnote draft, for the rail's words; and its highlights are
    /// over d3's own text, `flat` and `blocks` the kit's, in its rendering version, so the reader
    /// draws them as the Mac's would.
    public static func browserSuite(d3 flat: String, blocks: [String], renderingVersion: String) -> ResearchDataEnvelope {
        // The text's first three words, ended before a space or a line break, which the kit's
        // renderer at the pin cannot end a range after.
        let units = Array(flat.utf16)
        let start = units.firstIndex { $0 != 0x20 && $0 != 0x0A } ?? 0
        var end = start
        var spaces = 0
        while end < units.count, units[end] != 0x0A {
            if units[end] == 0x20 {
                spaces += 1
                if spaces == 3 { break }
            }
            end += 1
        }
        var envelope = everyType(formatVersion: 7)
        envelope.exportedForProjectName = nil
        envelope.exportedForProjectResearchQuestion = nil
        envelope.notes = [
            ResearchNoteExport(id: id(1), documentId: "d3", volumeId: "frus1961-63v06", bodyText: "Planners on Zapata.\nA second line.",
                               projectIds: [id(40)], userTagIds: [id(20)], selectedSummaryIds: [id(70)], linkedHighlightIds: [],
                               createdAt: date("2026-03-01T10:00:00Z"), lastModified: date("2026-03-02T10:00:00Z")),
            // Formatted as the Mac's editor writes it, which the codec reads.
            ResearchNoteExport(id: id(2), documentId: "d4", volumeId: "frus1961-63v06", bodyText: "The OAS meeting.",
                               projectIds: [id(40), id(41)], userTagIds: [], selectedSummaryIds: [], linkedHighlightIds: [],
                               createdAt: date("2026-03-03T10:00:00Z"), lastModified: date("2026-03-03T11:00:00Z"),
                               richText: Data(RTFWriter.write([RichTextRun(text: "The "), RichTextRun(text: "OAS", bold: true),
                                                               RichTextRun(text: " meeting.")]))),
            // With RTF whose text is another's, which the codec keeps as it came.
            ResearchNoteExport(id: id(3), documentId: "d5", volumeId: "frus1961-63v06", bodyText: "In no project.",
                               projectIds: [], userTagIds: [id(21)], selectedSummaryIds: [], linkedHighlightIds: [],
                               createdAt: date("2026-03-04T10:00:00Z"), lastModified: date("2026-03-04T12:34:56Z"),
                               richText: Data(#"{\rtf1\ansi\ansicpg1252\cocoartf2868 {\fonttbl\f0\fnil Helvetica;}\f0 Another text}"#.utf8)),
        ]
        envelope.projects = [
            ProjectExport(id: id(40), name: "Bay of Pigs review", researchQuestion: "What did the planners expect?",
                          defaultSubjectTagIds: [], defaultCountryTagIds: [], createdAt: date("2026-01-10T00:00:00Z"),
                          lastModified: date("2026-01-11T00:00:00Z"), defaultUserTagIds: [id(20)]),
            ProjectExport(id: id(41), name: "Cuba and the OAS", defaultSubjectTagIds: [], defaultCountryTagIds: [],
                          createdAt: date("2026-01-12T00:00:00Z"), lastModified: date("2026-01-12T00:00:00Z"), defaultUserTagIds: []),
        ]
        envelope.highlights = [
            DocumentHighlightExport(id: id(10), volumeId: "frus1961-63v06", documentId: "d3", startOffset: start, endOffset: end,
                                    colorTag: "blue", selectedText: flatTextExcerpt(blocks: blocks, start: start, end: end) ?? "",
                                    renderingVersion: renderingVersion, createdAt: date("2026-03-01T09:00:00Z")),
        ]
        envelope.notes[0].linkedHighlightIds = [id(10)]
        envelope.highlights[0].noteId = id(1)
        envelope.tagAssignments = [
            DocumentTagAssignmentExport(id: id(30), volumeId: "frus1961-63v06", documentId: "d3", tagId: id(20),
                                        createdAt: date("2026-02-03T00:00:00Z")),
        ]
        envelope.summaries = [
            GeneratedSummaryExport(id: id(70), documentId: "d3", volumeId: "frus1961-63v06", promptId: id(80),
                                   responseText: "The planners expected an uprising.", responseFormat: .general, wasChunked: false,
                                   createdAt: date("2026-05-03T00:00:00Z"), lastModified: date("2026-05-03T00:00:00Z"),
                                   authorship: .aiGenerated, isHeadnoteDraft: false),
            GeneratedSummaryExport(id: id(71), documentId: "d3", volumeId: "frus1961-63v06", promptId: standardPrompt,
                                   responseText: "An earlier summary, edited by hand.", responseFormat: .general, wasChunked: true,
                                   createdAt: date("2026-05-02T00:00:00Z"), lastModified: date("2026-05-02T00:00:00Z"),
                                   authorship: .aiEdited, isHeadnoteDraft: false),
            GeneratedSummaryExport(id: id(72), documentId: "d3", volumeId: "frus1961-63v06", promptId: id(80),
                                   responseText: "The researcher's own summary, from the Mac.", responseFormat: .general,
                                   wasChunked: false, createdAt: date("2026-05-01T00:00:00Z"),
                                   lastModified: date("2026-05-01T00:00:00Z"), authorship: .userWritten, isHeadnoteDraft: false),
            GeneratedSummaryExport(id: id(73), documentId: "d3", volumeId: "frus1961-63v06", promptId: headnotePrompt,
                                   responseText: "A headnote, private to the collection.", responseFormat: .general,
                                   wasChunked: false, createdAt: date("2026-05-04T00:00:00Z"),
                                   lastModified: date("2026-05-04T00:00:00Z"), authorship: .userWritten, isHeadnoteDraft: true),
        ]
        envelope.collections = envelope.collections.map { collection in
            var collection = collection
            collection.entries = collection.entries.map { entry in
                var entry = entry
                if entry.documentId == "d3", entry.kind == "document" { entry.selectedHighlightIds = [id(10)] }
                return entry
            }
            return collection
        }
        return envelope
    }
}
