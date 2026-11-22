// Corpus Analytics' and Chronology's routes (PLAN's S24f), over the synthetic export: what a request may ask and
// what is refused, the context both screens read, the export's attachment and the figure's plate, and the
// answer while no index is served. The charts themselves are held to the kit's over the fixture index in
// `CorpusAnalyticsParityTests` and `ChronologyParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct AnalyticsRouteTests {
    @Test func theRequestsAndRefusals() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let context = try decode(AnalyticsContext.self, try await client.execute(uri: "/api/v1/analytics/context", method: .get))
            #expect(context.floorYear == 1861 && context.earliestYear == 1776 && context.corpusMaxYear >= 1992)
            #expect(context.colorCounts == Array(6...12) && context.defaultColors == 8 && context.indexedVolumeCount > 0)
            #expect(context.chronologyTo == "\(context.corpusMaxYear)-12-31" && context.chronologyFrom == "\(context.corpusMaxYear - 1)-12-31")
            #expect(!context.presets.isEmpty && context.presets.allSatisfy { $0.start <= $0.end && $0.end <= context.corpusMaxYear })
            #expect(context.presets.contains { $0.label.hasPrefix("Abraham Lincoln (1861–") }, "\(context.presets.prefix(2))")
            #expect(!context.subseries.isEmpty && context.subseries.allSatisfy { !$0.volumes.isEmpty })
            #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/context?term=x", method: .get)) == "UNKNOWN_PARAMETER")

            let volume = try #require(context.subseries.first?.volumes.first)
            let chart = try decode(CorpusAnalyticsAnswer.self, try await client.execute(uri: "/api/v1/analytics/corpus?term=the", method: .get))
            #expect(chart.axis == "byYear" && chart.years.start == 1861 && chart.years.end == context.corpusMaxYear && !chart.years.isCustom)
            #expect(chart.scope.label == "Whole corpus" && chart.scope.volumeIds == nil && chart.colors == 8)
            let scoped = try decode(CorpusAnalyticsAnswer.self, try await client.execute(
                uri: "/api/v1/analytics/corpus?term=the&volume=\(volume.id)&from=1900&to=1950", method: .get))
            #expect(scoped.scope.label == volume.title && scoped.scope.volumeIds == [volume.id] && scoped.years.isCustom)
            let subseries = try #require(context.subseries.first)
            let bySubseries = try decode(CorpusAnalyticsAnswer.self, try await client.execute(
                uri: "/api/v1/analytics/corpus?term=the&subseries=\(subseries.name)", method: .get))
            #expect(bySubseries.scope.label == subseries.name && bySubseries.scope.volumeIds == subseries.volumes.map(\.id))
            let labelled = try decode(CorpusAnalyticsAnswer.self, try await client.execute(
                uri: "/api/v1/analytics/corpus?term=the&volumes=\(volume.id)&scopeLabel=Mine", method: .get))
            #expect(labelled.scope.label == "Mine")

            for (query, code) in [
                ("", "INVALID_PARAMETER"), ("term=%20", "INVALID_PARAMETER"), ("term=a%01b", "INVALID_PARAMETER"),
                ("term=\(String(repeating: "a", count: 1_001))", "INVALID_PARAMETER"),
                ("term=x&axis=byWeek", "INVALID_PARAMETER"), ("term=x&measure=words", "INVALID_PARAMETER"),
                ("term=x&values=percent", "INVALID_PARAMETER"), ("term=x&from=1700", "INVALID_PARAMETER"),
                ("term=x&to=2999", "INVALID_PARAMETER"), ("term=x&from=1950&to=1900", "INVALID_PARAMETER"),
                ("term=x&colors=5", "INVALID_PARAMETER"), ("term=x&colors=13", "INVALID_PARAMETER"),
                ("term=x&subseries=1700", "INVALID_PARAMETER"), ("term=x&volume=frus1800nowhere", "VOLUME_NOT_FOUND"),
                ("term=x&volumes=frus1800nowhere", "VOLUME_NOT_FOUND"), ("term=x&volumes=", "INVALID_PARAMETER"),
                ("term=x&topic=Nowhere", "INVALID_PARAMETER"), ("term=x&subtopic=Nowhere", "INVALID_PARAMETER"),
                ("term=x&scopeLabel=Mine", "INVALID_PARAMETER"),
                ("term=x&volume=\(volume.id)&subseries=\(subseries.name)", "INVALID_PARAMETER"),
                ("term=x&term=y", "INVALID_PARAMETER"), ("term=x&scope=all", "UNKNOWN_PARAMETER"),
            ] {
                #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/corpus?\(query)", method: .get)) == code, "\(query)")
            }
            // By Subject: an item with indexed volumes scopes the chart to them, under the menu's label; one with
            // none, a sub-category the menu does not offer, and a category alone are refused.
            let topic = try #require(context.topics.first { $0.items.contains { $0.indexed > 0 } }, "the synthetic export's volumes have subjects")
            let item = try #require(topic.items.first { $0.indexed > 0 })
            let query = "term=the&topic=\(Self.encoded(topic.label))&subtopic=\(Self.encoded(item.subcategory))"
            let byTopic = try decode(CorpusAnalyticsAnswer.self, try await client.execute(uri: "/api/v1/analytics/corpus?\(query)", method: .get))
            let indexed = Set(context.subseries.flatMap { $0.volumes.map(\.id) })
            #expect(byTopic.scope.label == "\(topic.label) · \(item.subcategory)" && byTopic.scope.volumeIds?.count == item.indexed)
            #expect(Set(byTopic.scope.volumeIds ?? []).isSubset(of: indexed) && item.label.hasSuffix("(\(item.indexed) of \(item.total) indexed)"))
            if let none = context.topics.flatMap({ category in category.items.map { (category.label, $0) } }).first(where: { $0.1.indexed == 0 }) {
                #expect(none.1.label == "\(none.1.subcategory) — none indexed yet")
                #expect(problemCode(try await client.execute(
                    uri: "/api/v1/analytics/corpus?term=the&topic=\(Self.encoded(none.0))&subtopic=\(Self.encoded(none.1.subcategory))",
                    method: .get)) == "INVALID_PARAMETER")
            }
            for refused in ["term=the&topic=\(Self.encoded(topic.label))&subtopic=Nowhere", "term=the&topic=\(Self.encoded(topic.label))",
                            "term=the&topic=Nowhere&subtopic=\(Self.encoded(item.subcategory))"] {
                #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/corpus?\(refused)", method: .get)) == "INVALID_PARAMETER", "\(refused)")
            }
            // A volume the index does not hold is no scope the menu offers; a sub-category or a label without its scope is
            // refused, not dropped.
            for refused in ["term=x&volume=frus1964-68v01", "term=x&subseries=\(subseries.name)&subtopic=x",
                            "term=x&volume=\(volume.id)&scopeLabel=Mine", "term=x&topic=\(Self.encoded(topic.label))&scopeLabel=Mine"] {
                #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/corpus?\(refused)", method: .get)) == "INVALID_PARAMETER", "\(refused)")
            }
            // A query with nothing left to search charts nothing, and Search refuses to count it, as its own route does.
            let excluded = try decode(CorpusAnalyticsAnswer.self, try await client.execute(uri: "/api/v1/analytics/corpus?term=-war", method: .get))
            #expect(excluded.state == "empty")
            #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/corpus/documents?term=-war", method: .get)) == "EMPTY_QUERY")
            // A figure is a chart's on a time view alone.
            for refused in ["term=zyzzyvaqq", "term=the&axis=bySubseries", "term=%3Dthe"] {
                #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/corpus/plate?\(refused)", method: .get)) == "NOTHING_TO_EXPORT", "\(refused)")
            }

            // An exact word is refused by the chart, so its documents are not counted.
            let exact = try decode(CorpusAnalyticsAnswer.self, try await client.execute(uri: "/api/v1/analytics/corpus?term=%3Dthe", method: .get))
            #expect(exact.state == "exactUnsupported" && exact.stateDetail?.hasPrefix("=the can’t be charted") == true)
            #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/corpus/documents?term=%3Dthe", method: .get)) == "NOTHING_TO_COUNT")
            let none = try decode(CorpusAnalyticsAnswer.self, try await client.execute(uri: "/api/v1/analytics/corpus?term=zyzzyvaqq", method: .get))
            #expect(none.state == "empty" && none.stateDetail == "No indexed documents match “zyzzyvaqq”.")
            #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/corpus/export?term=zyzzyvaqq", method: .get)) == "NOTHING_TO_EXPORT")

            // The export is an attachment, its name the app's, and the plate the kit's lines.
            let export = try await client.execute(uri: "/api/v1/analytics/corpus/export?term=the&timeZone=Europe/Paris", method: .get)
            #expect(export.status == .ok && export.headers[.contentType] == "text/csv; charset=utf-8")
            #expect(export.headers[.contentDisposition]?.hasPrefix("attachment; filename=\"FRUS-Analytics-the-By-Year-") == true)
            #expect(String(buffer: export.body).hasPrefix("# FRUS Explorer — analytics export\n#\n# Figure: \"the\" — By Year\n"))
            #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/corpus/export?term=the&timeZone=Mars/Olympus", method: .get))
                    == "INVALID_PARAMETER")
            let plate = try decode(AnalyticsPlate.self, try await client.execute(uri: "/api/v1/analytics/corpus/plate?term=the", method: .get))
            #expect(plate.lines.first?.role == "title" && plate.lines.first?.text == "\"the\" — By Year")
            #expect(plate.lines.map(\.role).suffix(2) == ["attribution", "dataPointer"] && plate.fileName.hasPrefix("FRUS-Analytics-the-By-Year-"))

            // Chronology.
            let range = "from=\(context.chronologyFrom)&to=\(context.chronologyTo)"
            let chronology = try decode(ChronologyAnswer.self, try await client.execute(uri: "/api/v1/chronology?\(range)", method: .get))
            #expect(chronology.from == context.chronologyFrom && chronology.to == context.chronologyTo && chronology.ascending)
            #expect(chronology.granularity == "day" && chronology.colors == 8 && chronology.filter == nil)
            for (query, code) in [
                ("", "INVALID_PARAMETER"), ("from=1969-01-01", "INVALID_PARAMETER"), ("from=1969-1-1&to=1969-12-31", "INVALID_PARAMETER"),
                ("from=1969-02-30&to=1969-12-31", "INVALID_PARAMETER"), ("from=0000-01-01&to=1969-12-31", "INVALID_PARAMETER"),
                ("\(range)&order=sideways", "INVALID_PARAMETER"), ("\(range)&colors=20", "INVALID_PARAMETER"),
                ("\(range)&series=frus1800nowhere", "INVALID_PARAMETER"), ("\(range)&term=x", "UNKNOWN_PARAMETER"),
            ] {
                #expect(problemCode(try await client.execute(uri: "/api/v1/chronology?\(query)", method: .get)) == code, "\(query)")
            }
            let dated = "from=1960-11-01&to=1960-11-30"
            let plateOfRange = try decode(AnalyticsPlate.self, try await client.execute(uri: "/api/v1/chronology/plate?\(dated)", method: .get))
            #expect(plateOfRange.lines.first?.text == "Chronology, 1960-11-01 to 1960-11-30")
            // A range with nothing on its chart has no figure, as it has no CSV.
            #expect(problemCode(try await client.execute(uri: "/api/v1/chronology/plate?from=1800-01-01&to=1800-12-31", method: .get))
                    == "NOTHING_TO_EXPORT")
            #expect(problemCode(try await client.execute(uri: "/api/v1/chronology/export?from=1800-01-01&to=1800-12-31", method: .get))
                    == "NOTHING_TO_EXPORT")
        }
        let waiting = try await UserDataFixture()
        defer { withExtendedLifetime(waiting) {} }
        try await waiting.app.test(.router) { client in
            for uri in ["/api/v1/analytics/context", "/api/v1/analytics/corpus?term=x", "/api/v1/chronology?from=1969-01-01&to=1969-12-31"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(response.status == .serviceUnavailable && problemCode(response) == "INDEX_NOT_READY", "\(uri)")
            }
        }
    }

    /// A query value, percent-encoded.
    static func encoded(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    /// The export's file name is the app's `AnalyticsExportDelivery.filenameStem`: the title's letters, digits,
    /// hyphens and underscores, spaces as hyphens, beside the prefix and the day.
    @Test func theExportsNameIsTheApps() throws {
        let day = try #require(ISO8601DateFormatter().date(from: "2026-11-14T12:00:00Z"))
        #expect(CorpusAnalyticsRoutes.filenameStem(title: "\"cold war\" — By Year", date: day) == "FRUS-Analytics-cold-war-By-Year-2026-11-14")
        #expect(CorpusAnalyticsRoutes.filenameStem(title: "—", date: day) == "FRUS-Analytics-chart-2026-11-14")
        let long = CorpusAnalyticsRoutes.filenameStem(title: String(repeating: "a", count: 400), date: day)
        #expect(ExportFileName.length(of: long) + 8 <= ExportFileName.maxLength && long.hasSuffix("-2026-11-14"))
    }
}
