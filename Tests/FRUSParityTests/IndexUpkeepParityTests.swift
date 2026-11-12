// The index's upkeep's mirrors of the app (PLAN's S21e), held to the app's source at the pin: the
// compaction's rule, `IndexCompaction` in `FRUSExplorer/Settings/SettingsComponents.swift`, app code, which
// `IndexCompactionRule` runs as written there; and the note beneath a side-loaded volume's citation,
// `DocumentViewModel.citationProvenanceNote`'s sentence, made the server's. Every other rule the upkeep
// follows is the kit's, compiled from the submodule.

import FRUSCoreKit
@testable import FRUSLightAPI
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct IndexUpkeepParityTests {
    static let settingsComponents = "FRUSExplorer/Settings/SettingsComponents.swift"
    static let documentViewModel = "FRUSExplorer/DocumentView/DocumentViewModel.swift"

    static func web(_ path: String) throws -> String {
        try String(contentsOf: RepositoryFiles.root.appendingPathComponent(path), encoding: .utf8)
    }

    /// The compaction's constants and its availability are the app's, line for line, but the name the
    /// enum is called by.
    @Test func theCompactionRuleIsTheApps() throws {
        let (app, web) = (try LibraryParityTests.app(Self.settingsComponents), try Self.web("Sources/FRUSLightCore/IndexUpkeep.swift"))
        for constant in ["static let minimumWorthwhileBytes = 200 * 1024 * 1024", "static let freeSpaceSafetyMargin = 1.15"] {
            #expect(app.contains(constant), "\(constant)")
            #expect(web.contains("public \(constant)"), "\(constant)")
        }
        let function = "static func availability(statistics: IndexPageStatistics?, availableBytes: Int?) -> Availability {"
        let appBody = try LibraryParityTests.block(function, in: app)
        #expect(appBody.count > 10)
        #expect(try LibraryParityTests.block("public " + function, in: web).dropFirst() == appBody.dropFirst())
        #expect(IndexCompactionRule.minimumWorthwhileBytes == 200 * 1024 * 1024 && IndexCompactionRule.freeSpaceSafetyMargin == 1.15)
    }

    /// The note is the app's sentence, the app's "The app cannot confirm" this server's.
    @Test func theSideloadedCitationsNoteIsTheApps() throws {
        let app = try LibraryParityTests.app(Self.documentViewModel)
        let key = #"String(localized: "citation.sideloaded.note","#
        #expect(app.contains(key))
        let lines = app.components(separatedBy: "\n")
        let at = try #require(lines.firstIndex { $0.contains(key) })
        let line = lines[at + 1].trimmingCharacters(in: .whitespaces)
        let sentence = try #require(line.split(separator: "\"", omittingEmptySubsequences: false).dropFirst().first.map(String.init))
        #expect(sentence.contains("The app cannot confirm it is published"))
        #expect(CitationRoutes.sideloadedNote == sentence.replacingOccurrences(of: "The app cannot confirm", with: "This server cannot confirm"))
    }
}
