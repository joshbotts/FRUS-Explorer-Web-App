// The user store's tables against the app's models at the pin (S14a): a table for each model type in
// `frusModelTypes`, and a column for each stored property, of the property's type. A pin move that
// adds a model or a stored property fails here until a migration and `UserStoreSchema` follow it.

@testable import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Testing

@Suite struct UserStoreParityTests {
    /// How a property of a type the app declares for itself is stored. A new one fails
    /// `eachColumnHoldsItsPropertysType` until it is named here.
    static let appTypes: [String: UserStoreSchema.Kind] = [
        // A `String` enumeration (GeneratedSummary.swift), kept as its raw value.
        "SummaryAuthorship": .text,
        // An enumeration with an associated value, and a struct (SupportingTypes.swift): JSON.
        "ResponseFormat": .json,
        "StructuredSummarySchema": .json,
    ]

    @Test func thereIsATableForEachModelTypeTheAppHolds() throws {
        let types = try AppModelSource.modelTypes()
        let inventory = try AppModelSource.storedProperties()
        #expect(types.count == 23, "frusModelTypes at the pin names 23 types")
        #expect(Set(types).count == types.count)
        #expect(Set(inventory.keys) == Set(types), "the CloudKit inventory names the same types as frusModelTypes")
        #expect(Set(UserStoreSchema.tables.map(\.model)) == Set(types),
                "a table for each model type: a type the pin adds needs a migration and a table")
        #expect(Set(UserStoreSchema.tables.map(\.name)).count == UserStoreSchema.tables.count)
        #expect(UserStoreSchema.tables.filter { $0.scope == .instance }.map(\.model).sorted()
                == ["DocumentClassificationOverride", "PersonClusterOverride"],
                "the two override types are instance-wide, as SPEC's mapping has them")
    }

    @Test func everyStoredPropertyHasAColumnOrARelationship() throws {
        let inventory = try AppModelSource.storedProperties()
        var named = 0
        for table in UserStoreSchema.tables {
            let stored = inventory[table.model] ?? []
            let kept = table.properties
            #expect(Set(kept).count == kept.count, "\(table.model) names a property twice")
            for property in stored.subtracting(kept).sorted() {
                Issue.record("\(table.model).\(property) is a stored property at the pin with no column in \(table.name): add a migration, and the column to UserStoreSchema")
            }
            for property in Set(kept).subtracting(stored).sorted() {
                Issue.record("\(table.name) keeps \(table.model).\(property), which is not a stored property at the pin")
            }
            named += Set(kept).intersection(stored).count
        }
        #expect(named == 249, "the 23 types' stored properties at the pin, relationships included")
    }

    /// The inventory is the app's own list, which only the app's Xcode tests hold to its classes,
    /// and the app's repository has no CI. So the classes are read too.
    @Test func theInventoryNamesWhatTheClassesStore() throws {
        let inventory = try AppModelSource.storedProperties()
        var computed = 0
        for model in try AppModelSource.modelTypes() {
            let members = try AppModelSource.declarations(of: model)
            let stored = Set(members.filter(\.value.stored).keys)
            computed += members.count - stored.count
            #expect(stored == inventory[model] ?? [],
                    "\(model): its class stores \(stored.subtracting(inventory[model] ?? []).sorted()) beyond the inventory, which names \((inventory[model] ?? []).subtracting(stored).sorted()) beyond the class")
        }
        #expect(computed > 0, "the reading tells a computed property from a stored one")
    }

    @Test func eachColumnHoldsItsPropertysType() throws {
        let models = Set(UserStoreSchema.tables.map(\.model))
        for table in UserStoreSchema.tables {
            let declared = try AppModelSource.declarations(of: table.model)
            for column in table.columns {
                guard let type = declared[column.property]?.type else {
                    Issue.record("no declaration of \(table.model).\(column.property) in its class")
                    continue
                }
                let optional = type.hasSuffix("?")
                let base = optional ? String(type.dropLast()) : type
                #expect(column.optional == optional, "\(table.model).\(column.property) is \(type)")
                let kinds = try Self.kinds(for: base, property: column.property)
                #expect(kinds.contains(column.kind),
                        "\(table.model).\(column.property) is \(type), kept as \(column.kind.rawValue); expected one of \(kinds.map(\.rawValue).sorted())")
            }
            let names = Set(table.columns.map(\.property))
            for relationship in table.relationships {
                let type = declared[relationship.property]?.type ?? ""
                switch relationship {
                case .toOne(let property, let heldBy):
                    #expect(models.contains(type.replacingOccurrences(of: "?", with: "")),
                            "\(table.model).\(property) is \(type), not one model")
                    #expect(names.contains(heldBy), "\(table.model).\(property) is held by \(heldBy), a column of \(table.name)")
                    #expect(table.columns.first { $0.property == heldBy }?.kind == .uuid)
                case .toMany(let property, let other, let heldBy):
                    let element = type.trimmingCharacters(in: CharacterSet(charactersIn: "[]?"))
                    #expect(type.hasPrefix("[") && models.contains(element), "\(table.model).\(property) is \(type), not a list of models")
                    let target = UserStoreSchema.tables.first { $0.name == other }
                    #expect(target?.model == element, "\(table.model).\(property) lists \(element), whose table is not \(other)")
                    #expect(target?.columns.contains { $0.property == heldBy && $0.kind == .uuid } == true,
                            "\(other).\(heldBy) holds the id of the \(table.model) that lists it")
                    #expect(target?.relationships.contains { if case .toOne(_, let by) = $0 { by == heldBy } else { false } } == true,
                            "\(other) keeps its side of \(table.model).\(property) by \(heldBy)")
                }
            }
        }
    }

    /// The kinds a property of the Swift type `type` may be kept as.
    static func kinds(for type: String, property: String) throws -> Set<UserStoreSchema.Kind> {
        let models = Set(UserStoreSchema.tables.map(\.model))
        return switch type {
        case "String": [.text]
        case "UUID": [.uuid]
        case "Int": [.integer]
        case "Double": [.real]
        case "Bool": [.boolean]
        case "Date": [.date]
        // Data the app writes with JSONEncoder, or as a kit type's `encoded` blob, becomes JSON text,
        // as SPEC has `parametersData`; any other, RTF or a payload not yet defined, stays bytes.
        case "Data": try AppModelSource.isWrittenAsJSON(property) ? [.json] : [.blob]
        // A list of models is a relationship, never a column.
        case _ where type.hasPrefix("[") && models.contains(type.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))): []
        default: type.hasPrefix("[") ? [.json] : appTypes[type].map { [$0] } ?? []
        }
    }

    @Test func theReadingOfAClassSkipsCommentsAndStrings() throws {
        let source = #"""
            @Model final class Sample {
                var id: UUID = UUID()
                /* a { nested /* } */ comment */
                var label: String { "\(flag ? "{" : "")" }
                var raw: String = #"C:\"#
                var note: String = """
                    } a brace in a multi-line string
                    """
                var name: String = "" {
                    didSet { print("}") }
                }
                // var commented: Int
                static var shared: Int = 0
                var tags: [String] = []
            }
            """#
        let code = Code(Substring(source)).blanked
        #expect(code.count == source.count, "offsets are kept")
        let start = try #require(code.range(of: "class Sample"))
        let body = try #require(Code.body(in: code, after: start.upperBound))
        let members = Code.memberDeclarations(in: code[body])
        #expect(members.filter(\.value.stored).keys.sorted() == ["id", "name", "note", "raw", "tags"])
        #expect(members["label"]?.stored == false, "a computed property")
        #expect(members["tags"]?.type == "[String]")
    }

    @Test func dataTheAppWritesAsJSONIsTheDataKeptAsJSON() throws {
        var json: [String] = []
        for table in UserStoreSchema.tables {
            let declared = try AppModelSource.declarations(of: table.model)
            for column in table.columns where declared[column.property]?.type.hasPrefix("Data") == true {
                if try AppModelSource.isWrittenAsJSON(column.property) { json.append("\(table.model).\(column.property)") }
            }
        }
        #expect(json.sorted() == ["ArchiveVisitPlan.deliverableTogglesData", "ArchiveVisitPlan.tiersData",
                                  "SavedSearch.freshnessData", "SavedSearch.parametersData"])
    }

    @Test func theMigratedStoreHasEachColumnAsTheSchemaDescribesIt() async throws {
        let directory = try TemporaryDirectory()
        _ = try await SQLiteUserStore(url: directory.url.appendingPathComponent("app.db"),
                                      backupsDirectory: directory.url.appendingPathComponent("backups"))
        let db = try SQLiteConnection(directory.url.appendingPathComponent("app.db").path, readOnly: true)
        defer { db.close() }
        for table in UserStoreSchema.tables {
            // (name, declared type, NOT NULL, position in the key); and no defaults, so a writer names
            // every value.
            let actual = try db.query("SELECT name, type, \"notnull\", pk FROM pragma_table_info(?)", [.text(table.name)])
                .map { "\($0[0].text ?? "") \($0[1].text ?? "") \($0[2].integer == 1 ? "NOT NULL" : "NULL") \($0[3].integer ?? 0)" }
            let defaults = try db.query("SELECT name FROM pragma_table_info(?) WHERE dflt_value IS NOT NULL", [.text(table.name)])
            #expect(defaults.isEmpty, "\(table.name) gives \(defaults.compactMap(\.first?.text)) a default")
            let foreign = try db.query("SELECT \"table\", \"from\", \"to\", on_delete FROM pragma_foreign_key_list(?)",
                                       [.text(table.name)]).map { $0.compactMap(\.text) }
            #expect(foreign == (table.scope == .user ? [["users", "user_id", "user_id", "CASCADE"]] : []),
                    "\(table.name): a user's rows go with the user, and refer to nothing else")
            var expected: [String] = []
            func key(_ name: String) -> Int { (table.primaryKey.firstIndex(of: name) ?? -1) + 1 }
            if table.scope == .user { expected.append("user_id TEXT NOT NULL \(key("user_id"))") }
            expected += table.columns.map { "\($0.name) \($0.kind.sqlType) \($0.optional ? "NULL" : "NOT NULL") \(key($0.name))" }
            #expect(actual == expected, "\(table.name) as migrations build it")
        }
        let tables = Set(try db.query("SELECT name FROM sqlite_master WHERE type = 'table'").compactMap { $0[0].text })
        let shadows = ["data", "idx", "content", "docsize", "config"].map { "user_search_\($0)" }
        #expect(tables == Set(UserStoreSchema.tables.map(\.name) + ["users", "schema_migrations", "user_search"] + shadows),
                "the store holds the users, its migrations, the 23 tables and user_search, and nothing else")
    }

    @Test func userSearchHoldsTheIndexedColumnsOfTheMacsUserContent() async throws {
        let directory = try TemporaryDirectory()
        _ = try await SQLiteUserStore(url: directory.url.appendingPathComponent("app.db"),
                                      backupsDirectory: directory.url.appendingPathComponent("backups"))
        let db = try SQLiteConnection(directory.url.appendingPathComponent("app.db").path, readOnly: false)
        defer { db.close() }
        let sql = try #require(try db.scalar("SELECT sql FROM sqlite_master WHERE name = 'user_search'")?.text)
        #expect(sql.contains("tokenize = '\(FTS5Schema.userContent.resolvedTokenizerName)'"), "the corpus's tokenizer")
        let columns = try db.query("SELECT name FROM pragma_table_info('user_search')").compactMap { $0[0].text }
        #expect(columns == ["user_id", "document_id", "volume_id", "summary_text", "note_text"])
        let indexed = FTS5Schema.userContent.indexedColumns.map(\.rawValue)
        #expect(indexed == ["summary_text", "note_text"])
        for column in columns {
            let unindexed = sql.contains("\(column) UNINDEXED")
            #expect(unindexed == !indexed.contains(column), "\(column) is \(unindexed ? "unindexed" : "indexed")")
        }

        _ = try db.query("INSERT INTO user_search (user_id, document_id, volume_id, summary_text, note_text) VALUES (?, ?, ?, ?, ?)",
                         [.text("owner"), .text("d12"), .text("frus1961-63v06"), .text("A summary."),
                          .text("Negotiating the Laos settlement")])
        let found = try db.query("SELECT volume_id, document_id FROM user_search WHERE user_search MATCH ? AND user_id = ?",
                                 [.text("negotiate"), .text("owner")])
        #expect(found == [[.text("frus1961-63v06"), .text("d12")]], "porter stems a note's words as the corpus's")
    }

    @Test func aUsersRowsGoWithTheUserAndTheInstancesStay() async throws {
        let directory = try TemporaryDirectory()
        let store = try await SQLiteUserStore(url: directory.url.appendingPathComponent("app.db"),
                                              backupsDirectory: directory.url.appendingPathComponent("backups"))
        try store.record(ClassificationOverride(volumeId: "frus1961-63v06", documentId: "d1", isEditorialNote: true,
                                                parsedIsEditorialNote: false))
        let db = try SQLiteConnection(directory.url.appendingPathComponent("app.db").path, readOnly: false)
        defer { db.close() }
        try db.execute("PRAGMA foreign_keys = ON")
        try db.execute("""
            INSERT INTO users (user_id, display_name, created_at) VALUES ('reader', 'Reader', '2026-10-24T00:00:00Z');
            INSERT INTO tags (user_id, id, name, created_at, last_modified) VALUES ('owner', 'A', 'Revisit', NULL, NULL);
            INSERT INTO tags (user_id, id, name, created_at, last_modified) VALUES ('reader', 'A', 'Revisit', NULL, NULL);
            """)
        #expect(try db.scalar("SELECT count(*) FROM tags WHERE id = 'A'")?.integer == 2,
                "two users may hold the same Mac id, as two imports of one file would")
        #expect(throws: SQLiteError.self) {
            try db.execute("INSERT INTO tags (user_id, id, name) VALUES ('nobody', 'B', 'x')")
        }
        for user in ["owner", "reader"] {
            _ = try db.query("INSERT INTO user_search (user_id, document_id, volume_id, summary_text, note_text) VALUES (?, 'd1', 'frus1961-63v06', '', 'A note')",
                             [.text(user)])
        }
        try db.execute("DELETE FROM users WHERE user_id = 'reader'")
        #expect(try db.query("SELECT user_id FROM tags") == [[.text("owner")]])
        #expect(try db.query("SELECT user_id FROM user_search") == [[.text("owner")]], "and so do their rows in user_search")
        #expect(try store.classificationOverrides().count == 1)
    }
}
