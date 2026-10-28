// The app's words and the few lines of its view code that the browser app's search takes for the
// researcher's own writing (PLAN's S17d, and PLAN's rule for view code: "mirrored with a parity test
// that reads the app's source at the pin"), read from the app's source and from web/src at once: the
// Mac's Search in row (`ScopeChip`, `SearchSheet.scopeRow`) and its refusal with every scope off; the
// filter's My Tags section, its summary, its counts' sentence and their spoken words; the Tags token's
// field and value (`tagFilterLabel`); and a result row's ◆ chips, the first three of
// `UserTag.chips(for:among:)`, which web/src/search/tagRules.ts mirrors. A pin move that changes one
// fails here until the web follows it.

import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct SearchViewParityTests {
    /// The app's source at `path`, flattened.
    static func app(_ path: String) throws -> String {
        NoteViewParityTests.flattened(try NoteViewParityTests.read(NoteViewParityTests.app, path))
    }

    static func web(_ path: String) throws -> String {
        NoteViewParityTests.flattened(try NoteViewParityTests.read(NoteViewParityTests.web, path))
    }

    /// Each word the web takes, where the app's source writes it under its key, and in copy.ts's search
    /// block where the screen reads it.
    @Test func theAppsWordsAreTheWebs() throws {
        let copy = try NoteViewParityTests.block("search", of: try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts"))
        let sheet = try Self.app("App/SearchSheet.swift")
        let model = try Self.app("App/MacSearchViewModel.swift")
        let filter = try Self.app("Search/SearchFilterView.swift")
        let tokens = try Self.app("App/SearchFilterTokens.swift")
        let words: [(source: String, file: String, key: String, value: String, web: String)] = [
            (sheet, "SearchSheet", "search.scope.searchIn", "Search in", "searchIn: 'Search in'"),
            (sheet, "SearchSheet", "search.scope.documents.label", "Documents", "documents: 'Documents'"),
            (sheet, "SearchSheet", "search.scope.notes.label", "Notes", "notes: 'Notes'"),
            (sheet, "SearchSheet", "search.scope.summaries.label", "Summaries", "summaries: 'Summaries'"),
            (filter, "SearchFilterView", "search.section.usertags", "My Tags", "myTags: 'My Tags'"),
            (filter, "SearchFilterView", "search.scope.any", "Any", "(count === 0 ? 'Any' :"),
            (filter, "SearchFilterView", "search.usertags.countFooter", "Counts are documents in your current results carrying that tag.",
             "myTagsCountFooter: 'Counts are documents in your current results carrying that tag.'"),
            (tokens, "SearchFilterTokens", "search.token.field.tags", "Tags", "tags: 'Tags'"),
            (model, "MacSearchViewModel", "search.filter.tags.unresolved", "1 tag", "unresolved: '1 tag'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(copy.contains(word.web), "copy.ts's search block holds \(word.web)")
        }
        // The help on each chip, which the app writes across lines; Summaries' is the web's own, since
        // the web keeps the summaries a researcher writes as well as those generated.
        for (key, value, web) in [
            ("search.scope.documents.help", "Search the full text of FRUS documents (header, dateline, source note, body)",
             "documents: 'Search the full text of FRUS documents (header, dateline, source note, body)'"),
            ("search.scope.notes.help", "Search the body text of your research notes", "notes: 'Search the body text of your research notes'"),
            ("search.scope.summaries.help", "Search the text of generated AI summaries",
             "summaries: 'Search the text of generated AI summaries and your own'"),
        ] {
            #expect(sheet.contains(#"localized: "\#(key)", defaultValue: "\#(value)""#), "SearchSheet writes \(key)")
            #expect(copy.contains(web), "copy.ts holds \(web)")
        }
        // The refusal with every scope off, written across lines too.
        #expect(model.contains(#"localized: "search.error.emptyScope", defaultValue: "Enable at least one of Documents, Notes, or Summaries to search.""#))
        #expect(copy.contains("emptyScope: 'Enable at least one of Documents, Notes, or Summaries to search.'"))
        // The words with a count in them, as functions of it.
        #expect(filter.contains(#"String(localized: "search.scope.selectedCount %lld", defaultValue: "%lld selected"), Int64(count))"#))
        #expect(copy.contains("`${count.toLocaleString('en-US')} selected`"))
        #expect(model.contains(#"String(localized: "search.filter.tags.count", defaultValue: "\(parameters.userTagIds.count) tags")"#))
        #expect(copy.contains("count: (count: number) => `${count.toLocaleString('en-US')} tags`"))
        #expect(filter.contains(#"String(localized: "search.usertags.a11y", defaultValue: "\(tag.name): \(count) documents in your current results")"#))
        #expect(copy.contains("myTagCount: (name: string, count: number) => `${name}: ${count.toLocaleString('en-US')} documents in your current results`"))
    }

    /// The chips' rule and the token's value, as the app's code says them and tagRules.ts mirrors them:
    /// a chip for each id the tag list names, each once, in the row's order, three drawn, each as ◆ and
    /// the name; and one tag's name, "1 tag" for one the list does not name, and a count for several.
    @Test func theRowsChipsAndTheTokensValueAreTheMirrors() throws {
        let chips = try Self.app("Models/UserTag.swift")
        NoteViewParityTests.expect(chips, holds: [
            "static func chips(for tagIds: [String], among tags: [UserTag]) -> [UserTagChip] {",
            "for tag in tags { names[tag.id.uuidString] = tag.name }",
            "var seen: Set<String> = []",
            "return tagIds.compactMap { tagId in guard let name = names[tagId], seen.insert(tagId).inserted else { return nil }",
        ], file: "UserTag.swift")
        let sheet = try Self.app("App/SearchSheet.swift")
        NoteViewParityTests.expect(sheet, holds: [
            "let chips = UserTag.chips(for: result.userTagIds, among: userTags) if !chips.isEmpty {",
            #"ForEach(chips.prefix(3)) { chip in Text("◆ \(chip.name)")"#,
        ], file: "SearchSheet.swift")
        let model = try Self.app("App/MacSearchViewModel.swift")
        NoteViewParityTests.expect(model, holds: [
            "guard !parameters.userTagIds.isEmpty else { return nil } guard parameters.userTagIds.count == 1 else {",
            "if let name = filterVM?.availableUserTags.first(where: { $0.id.uuidString == id })?.name { return name }",
        ], file: "MacSearchViewModel.swift")
        let rules = try Self.web("search/tagRules.ts")
        NoteViewParityTests.expect(rules, holds: [
            "if (tag === undefined || seen.has(key)) continue;",
            "export const rowChipLimit = 3;",
            "if (tagIds.length !== 1 || only === undefined) return copy.search.tagsToken.count(tagIds.length);",
            "return tags?.find((tag) => caseFolded(tag.id) === key)?.name ?? copy.search.tagsToken.unresolved;",
        ], file: "tagRules.ts")
        let screen = try Self.web("search/SearchScreen.tsx")
        NoteViewParityTests.expect(screen, holds: [
            "const chips = tags ? tagChips(tagIds, tags).slice(0, rowChipLimit) : [];",
            #"<span aria-hidden="true">◆ </span>"#,
        ], file: "SearchScreen.tsx")
    }
}
