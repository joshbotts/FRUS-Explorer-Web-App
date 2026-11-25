// Administration ▸ Semantic's Vectors (PLAN's S26c), read from the app's source and from web/src at once: the app's
// Semantic Vectors section (`SemanticStorageSection`) and its report's sentences (`SemanticStorageReport`), in a
// server's words, the shards "in the image" where the app's are downloaded "on this device", and nothing to download
// or remove. The server checks every shard in its image before it says what it found, so where the app's Problems
// say that its list is partial, the server's say what it checked. A pin move that changes one fails here until the
// web follows it.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct SemanticStorageMirrorParityTests {
    /// copy.ts's `admin.semantic.vectors` block, flattened.
    static func vectorsBlock() throws -> String {
        let semantic = try SemanticMirrorParityTests.semanticBlock()
        let start = try #require(semantic.range(of: "vectors: {"), "copy.ts has admin.semantic.vectors")
        return String(semantic[start.lowerBound...])
    }

    @Test func theSectionsRowsAreTheAppsInAServersWords() throws {
        let sources = NoteViewParityTests.Sources()
        let section = try sources.app("Settings/SemanticStorageSection.swift")
        let block = try Self.vectorsBlock()
        #expect(NoteViewParityTests.writes(section, "settings.vectors.header", SemanticStorageWords.header))
        #expect(block.contains("header: '\(SemanticStorageWords.header)'"))
        // Downloaded on this device, in the image on this server.
        #expect(NoteViewParityTests.writes(section, "settings.vectors.downloaded.label", "Downloaded"))
        #expect(SemanticStorageWords.heldLabel == "In the Image" && block.contains("held: 'In the Image'"))
        #expect(NoteViewParityTests.writes(section, "settings.vectors.downloaded.value %lld %lld", "%lld of %lld"))
        #expect(SemanticStorageWords.heldValue(3, of: 553) == "3 of 553")
        #expect(NoteViewParityTests.writes(section, "settings.vectors.downloaded.detail %@ %@", "%@ of %@ on this device."))
        #expect(SemanticStorageWords.heldDetail(199_368, of: 162_377_248) == "199 KB of 162.4 MB on this server.")
        #expect(block.contains("of ${published.toLocaleString('en-US')} — ${bytes} of ${publishedBytes} on this server.`"))
        // The section's sizes are ByteCountFormatter's, which both of the server's writers follow.
        #expect(section.contains("ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)"))
        #expect(NoteViewParityTests.writes(section, "settings.vectors.problems.label", SemanticStorageWords.problemsLabel))
        #expect(block.contains("problems: '\(SemanticStorageWords.problemsLabel)'"))
        // A build that cannot match by subject: the app's version, the server.
        #expect(NoteViewParityTests.writes(section, "settings.vectors.unavailable.label", SemanticStorageWords.unavailableLabel))
        let unavailable = "This version of the app cannot match documents by subject, so that part of Related Documents is unavailable. Nothing is wrong with your library."
        #expect(NoteViewParityTests.writes(section, "settings.vectors.unavailable.detail.v2", unavailable))
        let server = unavailable.replacingOccurrences(of: "This version of the app", with: "This server")
            .replacingOccurrences(of: "your library", with: "its library")
        #expect(SemanticStorageWords.unavailable == server && block.contains("unavailable: '\(server)'"))
        // The footer: the app's, the server's, each volume's file in the image where the app's downloads with it; its
        // sentence on Related Documents' panel stands since S26d, which puts the semantic matches there.
        let footer = "The app can find documents on the same subject even when they use none of the same words. Matches appear in the Related Documents panel, in a section of their own. Each volume needs a small extra file for this, which downloads with the volume and is removed with it (unless you disabled this). The feature is experimental, and how well it works on nineteenth-century material is not yet established."
        #expect(NoteViewParityTests.writes(section, "settings.vectors.footer.v4", footer))
        let serverFooter = footer.replacingOccurrences(of: "The app can", with: "The server can")
            .replacingOccurrences(of: "which downloads with the volume and is removed with it (unless you disabled this)", with: "which the image holds for every volume")
        #expect(block.contains("footer: '\(serverFooter)'"))
        // Nothing to download or remove: the app's controls have no words on the server.
        for (key, label) in [("settings.vectors.download.label", "Download Missing Vectors"),
                             ("settings.vectors.downloadAll.label", "Download Vectors for Every Volume"),
                             ("settings.vectors.remove.label", "Remove Downloaded Vectors"),
                             ("settings.vectors.auto.label", "Download With Volumes"),
                             ("settings.vectors.retry.label", "Try Failed Downloads Again")] {
            #expect(NoteViewParityTests.writes(section, key, label), "the app's section has \(label)")
            #expect(!block.contains(label), "the pane has no \(label)")
        }
    }

    @Test func theRefusalsAreTheAppsSentencesInAServersWords() throws {
        let report = try NoteViewParityTests.Sources().app("Semantic/SemanticStorageReport.swift")
        // The app's remedies remove a file and download it again, which nothing in an image can be: the server's
        // sentences end before them.
        let provenance = "This file was made for a different version of the app, so it cannot be used with this one. Remove it and download again."
        #expect(NoteViewParityTests.writes(report, "settings.vectors.refused.provenance.v2", provenance))
        #expect(SemanticStorageWords.otherVersion == provenance.replacingOccurrences(of: " Remove it and download again.", with: ""))
        let malformed = "The file on disk is damaged and was not used. Remove it and download again."
        #expect(NoteViewParityTests.writes(report, "settings.vectors.refused.malformed", malformed))
        #expect(SemanticStorageWords.damaged == malformed.replacingOccurrences(of: " Remove it and download again.", with: "")
            .replacingOccurrences(of: "on disk", with: "in the image"))
        #expect(NoteViewParityTests.writes(report, "settings.vectors.refused.missing.v2", "The file is no longer on this device."))
        #expect(SemanticStorageWords.missing == "The file is not in the image.")
        let intact = "The file did not arrive intact, so the app discarded it. Downloading again usually fixes this."
        #expect(NoteViewParityTests.writes(report, "settings.vectors.error.integrity.v2", intact))
        #expect(SemanticStorageWords.notIntact == "The file did not arrive intact, so the server does not use it.")
        #expect(NoteViewParityTests.writes(report, "settings.vectors.error.notPublished.v2", SemanticStorageWords.notPublished))
        #expect(NoteViewParityTests.writes(report, "settings.vectors.refused.pending", SemanticStorageWords.pending))
        // The two cases that are no fault stay out of the list, as the app's `describe` gives them no sentence.
        #expect(report.contains("case .noArtifact, .documentNotVectorised: return nil"))
        #expect(!SemanticShardRefusal.notPublished.isFault && SemanticShardRefusal.missing.isFault)
    }

    @Test func theProblemsCaptionSaysWhatTheServerChecked() throws {
        let report = try NoteViewParityTests.Sources().app("Semantic/SemanticStorageReport.swift")
        // The app's caption says its list is partial, and why: a problem is noticed only when a volume is downloaded
        // or searched.
        #expect(NoteViewParityTests.writes(report, "settings.vectors.problems.none.v2",
                                           "Nothing has gone wrong since the app opened. The app only notices a problem when it downloads or searches a volume, so this does not mean every file is good."))
        #expect(NoteViewParityTests.writes(report, "settings.vectors.problems.some.v2 %lld",
                                           "%lld found since the app opened. There may be others in volumes nothing has searched yet."))
        // The server checks every shard first, so its caption opens as the app's and says what it checked.
        #expect(SemanticStorageWords.problemsCaption(0, checked: 553)
            == "Nothing has gone wrong. The server checked all 553 files in its image against the bundled manifest.")
        #expect(SemanticStorageWords.problemsCaption(2, checked: 553)
            == "2 found. The server checked all 553 files in its image against the bundled manifest.")
        #expect(SemanticStorageWords.problemsCaption(553, checked: 0)
            == "553 found. The image holds none of the files the bundled manifest names.")
        let block = try Self.vectorsBlock()
        #expect(block.contains("return count === 0 ? `Nothing has gone wrong. ${scope}` : `${count.toLocaleString('en-US')} found. ${scope}`;"))
        #expect(block.contains("in its image against the bundled manifest.`;"))
        #expect(block.contains("? 'The image holds none of the files the bundled manifest names.'"))
    }
}
