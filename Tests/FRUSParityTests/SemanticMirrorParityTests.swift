// Search by meaning's words (PLAN's S27b), read from the app's source and from web/src at once: the server's
// refusals of a query too long for the model and of a search the encoder could not run, which the server gives
// in the app's words, and Administration ▸ Semantic's Search Model, the app's Settings section
// (`SemanticModelSection`) in a server's words: "this device" the server's, and the model "in the image" where
// the app's is "an optional 310 MB download". A pin move that changes one fails here until the web follows it.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct SemanticMirrorParityTests {
    /// copy.ts's `admin.semantic` block, flattened.
    static func semanticBlock() throws -> String {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let start = try #require(raw.range(of: "\n    semantic: {"), "copy.ts has admin.semantic")
        let end = try #require(raw.range(of: "\n    },", range: start.upperBound..<raw.endIndex))
        return NoteViewParityTests.flattened(String(raw[start.lowerBound..<end.upperBound]))
    }

    @Test func theRefusalsAreInTheAppsWords() throws {
        let sources = NoteViewParityTests.Sources()
        let phone = try sources.app("Search/SearchViewModel.swift")
        let mac = try sources.app("App/MacSearchViewModel.swift")
        #expect(NoteViewParityTests.writes(phone, "search.semantic.error.tooLong", EncoderRefusal.tooLongWords))
        #expect(NoteViewParityTests.writes(mac, "search.semantic.error.tooLong.mac", EncoderRefusal.tooLongWords))
        #expect(NoteViewParityTests.writes(mac, "search.semantic.error.failed.mac", EncoderRefusal.failedWords))
        #expect(EncoderRefusal.tooLong(tokens: nil).description == "This search is too long for the model. Try a shorter phrasing.")
    }

    @Test func searchModelIsTheAppsSectionInAServersWords() throws {
        let section = try NoteViewParityTests.Sources().app("Settings/SemanticModelSection.swift")
        let block = try Self.semanticBlock()
        // The row's label and the model file's, as the app's.
        #expect(NoteViewParityTests.writes(section, "settings.model.present.label", "Search Model"))
        #expect(block.contains("searchModel: 'Search Model'"))
        #expect(NoteViewParityTests.writes(section, "settings.model.path.label", "Model File"))
        #expect(block.contains("modelFile: 'Model File'"))
        // The row's detail: downloaded on this device, in the image on this server.
        #expect(section.contains(NoteViewParityTests.flattened(
            #"String(localized: "settings.model.present.detail %@", defaultValue: "Downloaded and verified — %@ on this device.")"#)))
        #expect(block.contains("present: (size: string) => `In the image and verified — ${size} on this server.`"))
        // A build that cannot use the model: the app's version, the server.
        #expect(NoteViewParityTests.writes(section, "settings.model.unavailable.detail",
                                           "This version of the app cannot use the search model. Nothing is wrong with your library."))
        #expect(block.contains("unavailable: 'This server cannot use the search model. Nothing is wrong with its library.'"))
        // The footer: the app's, the server's, the model in the image where the app's is a download.
        let footer = "Lets the app understand searches phrased as questions, using a language model that runs entirely on this device — Google’s EmbeddingGemma 2, an optional 310 MB download. The feature is experimental."
        #expect(NoteViewParityTests.writes(section, "settings.model.footer", footer))
        let server = footer.replacingOccurrences(of: "Lets the app", with: "Lets the server")
            .replacingOccurrences(of: "this device", with: "this server")
            .replacingOccurrences(of: "an optional 310 MB download", with: "310 MB in the image")
        #expect(block.contains("footer: '\(server)'"))
        // Nothing to download or remove: the app's two buttons have no words on the web.
        for (key, label) in [("settings.model.download.label", "Download Search Model"), ("settings.model.remove.label", "Remove Search Model")] {
            #expect(NoteViewParityTests.writes(section, key, label), "the app's section has \(label)")
            #expect(!block.contains(label), "the pane has no \(label)")
        }
    }
}
