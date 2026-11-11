// The library's mirrors of the app (PLAN's S21c), held to the app's source at the pin: the scan of a
// volume's figures, `FigureImageLibrary.graphicNames(inVolumeAt:)` and its `FigureGraphicScanner`, app code
// in `FRUSExplorer/Downloads/DownloadManager.swift`, which the library runs as written there; and where
// and how the app asks: GitHub's listing with its headers, a figure's address, the image host's refusals,
// and the images a volume's text no longer names. Every other rule the library follows is the kit's,
// compiled from the submodule.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct LibraryParityTests {
    static let downloadManager = "FRUSExplorer/Downloads/DownloadManager.swift"
    static let manifestStore = "FRUSExplorer/Models/Manifest/ManifestStore.swift"

    static func app(_ path: String) throws -> String {
        try String(contentsOf: RepositoryFiles.root.appendingPathComponent("upstream/FRUS-Explorer").appendingPathComponent(path), encoding: .utf8)
    }

    static func library() throws -> String {
        try String(contentsOf: RepositoryFiles.root.appendingPathComponent("Sources/FRUSLightCore/Library.swift"), encoding: .utf8)
    }

    /// The text from the line that starts `head` to the brace that closes it, its comments and blank lines
    /// left out and each line's indentation with them.
    static func block(_ head: String, in source: String) throws -> [String] {
        let lines = source.components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix(head) }, "\(head)")
        var depth = 0
        var kept: [String] = []
        for line in lines[start...] {
            let code = line.trimmingCharacters(in: .whitespaces)
            depth += code.filter { $0 == "{" }.count - code.filter { $0 == "}" }.count
            if !code.isEmpty, !code.hasPrefix("//") { kept.append(code) }
            if depth == 0, kept.count > 1 || code.hasSuffix("}") { break }
        }
        return kept
    }

    /// The scanner and the function that runs it are the app's, line for line, but the name the function
    /// is called by.
    @Test func theFigureScanIsTheApps() throws {
        let (app, web) = (try Self.app(Self.downloadManager), try Self.library())
        let scanner = "private final class FigureGraphicScanner: NSObject, XMLParserDelegate {"
        #expect(try Self.block(scanner, in: web) == Self.block(scanner, in: app))
        #expect(try Self.block(scanner, in: app).count > 20)
        let function = "public static func graphicNames(inVolumeAt url: URL) -> [String]? {"
        #expect(try Self.block(function, in: web) == Self.block(function, in: app))
    }

    /// The app's addresses and rules, which the library follows: GitHub's listing, asked with the app's
    /// headers; a figure at history.state.gov's `frus/<volume>/<name>`; 403 and 404 a refusal, and a 200
    /// that is no PNG not kept; and the images the text no longer names removed, images alone.
    @Test func whereAndHowTheAppAsks() throws {
        let (store, manager, web) = (try Self.app(Self.manifestStore), try Self.app(Self.downloadManager), try Self.library())
        #expect(store.contains(#"URL(string: "https://api.github.com/repos/HistoryAtState/frus/contents/volumes")"#))
        #expect(LibrarySources.github.listing.absoluteString == "https://api.github.com/repos/HistoryAtState/frus/contents/volumes")
        for header in [#"request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")"#,
                       #"request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")"#] {
            #expect(store.contains(header), "\(header)")
        }
        #expect(web.contains(#""Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28""#))
        #expect(manager.contains(#"public static let remoteBase = URL(string: "https://static.history.state.gov/frus")!"#))
        #expect(manager.contains("return remoteBase.appendingPathComponent(volumeId).appendingPathComponent(fileName)"))
        #expect(LibrarySources.github.figure(volumeId: "frus1969-76ve09p1", fileName: "OpenPitMine.jpg.png")?.absoluteString
            == "https://static.history.state.gov/frus/frus1969-76ve09p1/OpenPitMine.jpg.png")
        #expect(manager.contains("if status == 403 || status == 404 { return .refused }"))
        #expect(manager.contains("guard (200..<300).contains(status), FigureImageLibrary.isPNG(data) else { return .failed }"))
        #expect(web.contains("if answer.status == 403 || answer.status == 404 {"))
        #expect(web.contains("guard (200..<300).contains(answer.status), FigureImagePNG.isPNG(answer.body) else {"))
        #expect(manager.contains(#"for name in present where name.hasSuffix(".png") && !fileNames.contains(name) {"#))
        #expect(web.contains(#"where present.hasSuffix(".png") && !wanted.contains(present) {"#))
        #expect(manager.contains("let fileNames = names.compactMap(FigureImageName.fileName(forGraphic:))"))
        #expect(web.contains("FigureImageName.fileName(forGraphic: name)"))
    }
}
