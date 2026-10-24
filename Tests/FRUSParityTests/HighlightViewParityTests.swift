// The few lines of the app's view code that the browser app's highlights mirror (PLAN's S15c, and
// PLAN's rule for view code: "mirrored with a parity test that reads the app's source at the pin"),
// read from the app's source and from web/src at once: the selection verbs and the colours in the
// kit's order with the kit's rule for a footnote, the app's rule for a selection in the text, the
// Mac bar's place and its wait before a clear, the reader's order and the review sheet's, the review
// sheet's stale lines, the shortcut, and the app's words the web takes. A pin move that changes one
// fails here until the web follows it.

import FRUSCoreKit
import FRUSLightTestSupport
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct HighlightViewParityTests {
    static let app = RepositoryFiles.root.appendingPathComponent("upstream/FRUS-Explorer/FRUSExplorer")
    static let web = RepositoryFiles.root.appendingPathComponent("web/src")

    static func read(_ base: URL, _ path: String) throws -> String {
        try String(contentsOf: base.appendingPathComponent(path), encoding: .utf8)
    }

    /// Text with each run of white space read as one space, for source split across lines.
    static func flattened(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The bar's verbs: the kit's `SelectionVerb.allInOrder`, each with its `needsDocumentOffsets`,
    /// the colours `HighlightColor.allCases`, as web/src/reader/highlightRules.ts and api/types.ts
    /// list them.
    @Test func theSelectionVerbsAreTheKitsInItsOrder() throws {
        let types = try Self.read(Self.web, "api/types.ts")
        let rules = try Self.read(Self.web, "reader/highlightRules.ts")
        let colors = try #require(types.firstMatch(of: /export const highlightColors: readonly HighlightColor\[\] = \[([^\]]*)\];/))
        let webColors = colors.1.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
        #expect(webColors == HighlightColor.allCases.map(\.rawValue))
        #expect(types.contains("export type HighlightColor = \(HighlightColor.allCases.map { "'\($0.rawValue)'" }.joined(separator: " | "));"))
        let others = rules.matches(of: /\{ kind: '(\w+)', needsDocumentOffsets: (true|false) \}/).map { "\($0.1) \($0.2)" }
        let web = webColors.map { "highlight(\($0)) true" } + others
        let kit = SelectionVerb.allInOrder.map { verb -> String in
            switch verb {
            case .highlight(let color): "highlight(\(color.rawValue)) \(verb.needsDocumentOffsets)"
            case .excerpt: "excerpt \(verb.needsDocumentOffsets)"
            case .lookUpInNARA: "lookUpInNARA \(verb.needsDocumentOffsets)"
            case .note: "note \(verb.needsDocumentOffsets)"
            }
        }
        #expect(web == kit)
        #expect(rules.contains("...highlightColors.map((color) => ({ kind: 'highlight' as const, color, needsDocumentOffsets: true as const })),"))
    }

    /// A selection in the text is the app's `hasOffsets`, in the browser app and in the host script;
    /// the bar sits 8 points above it, kept 8 inside the frame, as the Mac's in its web view; and a
    /// clear waits 200 ms, as the Mac's bar waits out a false one.
    @Test func theSelectionAndTheBarAreTheMacs() throws {
        let webView = try Self.read(Self.app, "TEI/FRUSDocumentWebView.swift")
        #expect(webView.contains("var hasOffsets: Bool { start >= 0 && end > start }"))
        let rules = try Self.read(Self.web, "reader/highlightRules.ts")
        #expect(rules.contains("return start >= 0 && end > start;"))
        #expect(ReaderHostScript.source.contains("if (!(start >= 0 && end > start)) { return null; }"))
        let bar = try Self.read(Self.app, "DocumentView/FloatingSelectionBar.swift")
        #expect(bar.contains("gap: CGFloat = 8") && bar.contains("let margin: CGFloat = 8"))
        // Centred on the selection and kept inside; above it, or below when it would clip; then kept
        // inside again: as barPosition places it.
        for line in ["let x = min(max(selection.midX, minX), maxX)", "let centreAbove = selection.minY - gap - halfH",
                     "let centreBelow = selection.maxY + gap + halfH", "} else if !below, cy - halfH - margin < 0 {",
                     "cy = centreBelow", "cy = min(max(cy, minY), maxY)"] {
            #expect(bar.contains(line), "\(line)")
        }
        #expect(bar.contains("func scheduleHide(after milliseconds: Int = 200)"))
        let mac = Self.flattened(try Self.read(Self.app, "App/MacDocumentView.swift"))
        #expect(mac.contains("selection: anchor, container: proxy.size, below: false))"), "the Mac's bar sits above the selection")
        #expect(rules.contains("const gap = 8;") && rules.contains("const margin = 8;"))
        for line in ["const centre = frame.left + selection.x + selection.w / 2;", "const above = frame.top + selection.y - gap - bar.height;",
                     "const below = frame.top + selection.y + selection.h + gap;", "const top = above >= visible.top + margin ? above : below;",
                     "left: clamp(centre - bar.width / 2, visible.left + margin, visible.right - margin - bar.width),",
                     "top: clamp(top, visible.top + margin, visible.bottom - margin - bar.height),"] {
            #expect(rules.contains(line), "\(line)")
        }
        let hook = try Self.read(Self.web, "reader/useReaderHighlights.tsx")
        #expect(hook.contains("const clearDelay = 200;"))
    }

    /// The reader draws a document's highlights in its query's order, by time, which the store gives
    /// (`UserHighlightTests`); the review sheet lists them by where they start, as the rail's
    /// Highlights section does; and its stale lines are `HighlightReview.status`'s.
    @Test func theOrdersAndTheStaleLinesAreTheApps() throws {
        for file in ["App/MacDocumentView.swift", "DocumentView/DocumentView.swift"] {
            #expect(try Self.read(Self.app, file).contains("sort: \\DocumentHighlight.createdAt"), "\(file)")
        }
        let sheet = try Self.read(Self.app, "DocumentView/DocumentChangeReviewSheet.swift")
        #expect(sheet.contains("sort: [SortDescriptor(\\DocumentHighlight.startOffset)])"))
        let rules = try Self.read(Self.web, "reader/highlightRules.ts")
        #expect(rules.contains("a.startOffset - b.startOffset ||"))
        let review = try Self.read(Self.app, "DocumentView/HighlightReview.swift")
        #expect(review.contains("if highlight.renderingVersion == currentVersion { return .aligned }"))
        #expect(review.contains("return .stale(hasPassage: !highlight.selectedText.isEmpty)"))
        #expect(rules.contains("return highlight.selectedText !== '' ? 'stale' : 'staleNoPassage';"))
    }

    /// The app's shortcut for Highlight Selection ▸ Yellow is ⇧⌘H, which the host script and the
    /// browser app take, with Ctrl in place of ⌘ off a Mac.
    @Test func theShortcutIsTheApps() throws {
        let menu = Self.flattened(try Self.read(Self.app, "App/FRUSExplorerApp.swift"))
        #expect(menu.contains(#"if color == .yellow { Button(color.displayName) { commands?.highlightSelection(color) } .keyboardShortcut("h", modifiers: [.command, .shift])"#))
        #expect(ReaderHostScript.source.contains("event.shiftKey && (event.metaKey || event.ctrlKey) && !event.altKey && (event.key === 'h' || event.key === 'H')"))
        let hook = try Self.read(Self.web, "reader/useReaderHighlights.tsx")
        #expect(hook.contains("event.shiftKey && (event.metaKey || event.ctrlKey) && !event.altKey && event.key.toLowerCase() === 'h'"))
    }

    /// The app's words the browser app takes, each where the app's source writes it, under its key:
    /// the colours, the bar's names for them and the menu's, the question a tap asks, and the review
    /// sheet's.
    @Test func theAppsWordsAreTheWebs() throws {
        // copy.ts's `highlights` block, where each word is the web's under the key the UI reads.
        let copy = try Self.read(Self.web, "copy.ts")
        let start = try #require(copy.range(of: "\n  highlights: {"))
        let end = try #require(copy.range(of: "\n  },", range: start.upperBound..<copy.endIndex))
        let block = Self.flattened(String(copy[start.lowerBound..<end.upperBound]))
        let words: [(file: String, key: String, value: String, web: String)] = [
            ("Models/DocumentHighlight.swift", "highlight.color.yellow", "Yellow", "yellow"),
            ("Models/DocumentHighlight.swift", "highlight.color.green", "Green", "green"),
            ("Models/DocumentHighlight.swift", "highlight.color.blue", "Blue", "blue"),
            ("Models/DocumentHighlight.swift", "highlight.color.pink", "Pink", "pink"),
            ("App/FRUSExplorerApp.swift", "menu.document.highlight", "Highlight Selection", "bar"),
            ("App/MacDocumentView.swift", "highlight.delete.title", "Remove Highlight", "removeTitle"),
            ("App/MacDocumentView.swift", "highlight.delete.message", "This highlight will be permanently removed.", "removeMessage"),
            ("App/MacDocumentView.swift", "highlight.delete.confirm", "Remove", "removeConfirm"),
            ("App/MacDocumentView.swift", "highlight.delete.cancel", "Cancel", "removeCancel"),
            ("DocumentView/DocumentChangeReviewSheet.swift", "document.review.highlights.header", "Highlights", "section"),
            ("DocumentView/DocumentChangeReviewSheet.swift", "document.review.highlight.remove", "Remove…", "remove"),
            ("DocumentView/DocumentChangeReviewSheet.swift", "document.review.highlight.noPassage", "Highlighted passage", "noPassage"),
            ("DocumentView/DocumentChangeReviewSheet.swift", "document.review.highlight.stale",
             "Made against an earlier version of the text — its position may have moved.", "stale"),
            ("DocumentView/DocumentChangeReviewSheet.swift", "document.review.highlight.stale.noPassage",
             "Made against an earlier version of the text, and the words it covered were not stored — it can only be checked by eye.",
             "staleNoPassage"),
        ]
        var sources: [String: String] = [:]
        for word in words {
            let source = try sources[word.file] ?? Self.flattened(Self.read(Self.app, word.file))
            sources[word.file] = source
            #expect(source.contains("String(localized: \"\(word.key)\", defaultValue: \"\(word.value)\")")
                    || source.contains("String(localized: \"\(word.key)\", defaultValue: \"\(word.value)\"))"),
                    "\(word.file) writes \(word.key) as \(word.value)")
            #expect(block.contains("\(word.web): '\(word.value)'"), "copy.highlights.\(word.web) is \(word.value)")
        }
        let bar = Self.flattened(try Self.read(Self.app, "DocumentView/FloatingSelectionBar.swift"))
        #expect(bar.contains("String(localized: \"selectionBar.highlightColor.a11y\", defaultValue: \"Highlight \\(color.displayName)\")"))
        #expect(copy.contains("highlightColor: (color: string) => `Highlight ${color}`,"))
    }
}
