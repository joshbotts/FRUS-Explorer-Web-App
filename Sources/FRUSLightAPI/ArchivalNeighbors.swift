// Archival Neighbors (PLAN's S22d): the documents drawn from the same archival source as a document, a volume's
// Sources row, a collection or a central-file class, as the app's `ArchivalNeighborsSheet` lists them, in its
// three scopes: This volume, This subseries and All volumes.
//
// The lists are the kit's three public queries (`IndexingPipeline.archivalNeighbors(forVolumeId:…)`,
// `archivalNeighbors(forLotFile:…)` and `collectionNeighbors(…)`), which order the rows, cut them at thirty,
// leave out the document itself, try the collection authority's aliases when nothing else matches, count the rows
// in the scope and write the line that names the source. The request's shape and the picker's rules are the
// sheet's (`ArchivalNeighborsRequest`, `ArchivalNeighborsContent.availableScopes`, `resolvedScopeVolumeIds`),
// mirrored, the scopes through Related Documents' mirror of the same rule (`RelatedDocumentsRoutes.scopes`), and
// held to the app's source by `SourceExplorerParityTests`.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// One archival source's neighbours in one scope.
public struct ArchivalNeighborsAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// The scopes the picker offers, in its order; empty when it shows none (a collection's, a class's).
    public var scopes: [String]
    /// The scope listed.
    public var scope: String
    /// The volume the scopes are anchored on: the document's, or the Sources row's.
    public var anchorVolumeId: String?
    /// The documents, at most thirty, in the kit's order.
    public var documents: [Row]
    /// How many share the source in the scope, which may exceed the rows: the sheet's overflow line.
    public var totalCount: Int
    /// The line under the title, the kit's.
    public var basis: String?

    /// A row, as the sheet's draws it: the head, or the document's id for none, its volume and dateline.
    public struct Row: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        public var title: String
        public var dateline: String?
    }
}

enum ArchivalNeighborsRoutes {
    /// The longest alias list a request may name.
    static let maximumAliases = 64

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/archival-neighbors") { request, _ -> ArchivalNeighborsAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["volumeId", "documentId", "year", "collection", "lotFile", "recordGroup", "series",
                                     "repository", "decimalClass", "jobNumber", "aliasLot", "aliasName", "anchor", "scope"])
            let asked = try neighborsRequest(query, resources: resources)
            let offered = asked.anchorVolumeId.map { RelatedDocumentsRoutes.scopes(for: $0, resources: resources) } ?? [.all]
            let scope = try query.choice("scope", among: RelatedScope.allCases) ?? asked.defaultScope
            guard offered.contains(scope) else {
                throw APIProblem(.badRequest, code: "SCOPE_NOT_OFFERED",
                                 detail: "These neighbours have no \(scope.rawValue) scope: the picker offers \(offered.map(\.rawValue).joined(separator: ", ")).")
            }
            let served = try await provider.served()
            let scopeVolumeIds = asked.anchorVolumeId.flatMap {
                RelatedDocumentsRoutes.volumeIds(of: scope, anchorVolumeId: $0, resources: resources)
            }
            let found = await load(asked, scopeVolumeIds: scopeVolumeIds, pipeline: served.pipeline)
            withExtendedLifetime(served) {}
            return ArchivalNeighborsAnswer(
                scopes: offered.count > 1 ? offered.map(\.rawValue) : [], scope: scope.rawValue,
                anchorVolumeId: asked.anchorVolumeId,
                documents: found.documents.map {
                    ArchivalNeighborsAnswer.Row(volumeId: $0.volumeId, documentId: $0.documentId,
                                                title: $0.header.isEmpty ? $0.documentId : $0.header, dateline: $0.dateline)
                },
                totalCount: found.totalCount, basis: found.basis)
        }
    }

    /// What a sheet is opened for (`ArchivalNeighborsRequest`): a document, a volume's Sources row, a collection's
    /// record or a central-file class.
    enum NeighborsRequest: Equatable {
        case document(volumeId: String, documentId: String, documentYear: Int?)
        case volumeSource(lotFile: String?, recordGroup: String?, series: String?, repository: String?, decimalClass: String?,
                          jobNumber: String?, aliasLotFileNorm: String?, aliasNames: [String], anchorVolumeId: String?)
        case collection(lotFileNorm: String?, repository: String?, recordGroup: String?, names: [String])
        case decimalClass(String)

        /// The sheet's `anchorVolumeId`: the document's volume, or the Sources row's.
        var anchorVolumeId: String? {
            switch self {
            case .document(let volumeId, _, _): return volumeId
            case .volumeSource(_, _, _, _, _, _, _, _, let anchor): return anchor
            case .collection, .decimalClass: return nil
            }
        }

        /// The sheet's `defaultScope`: This volume for a Sources row, All volumes otherwise.
        var defaultScope: RelatedScope {
            switch self {
            case .volumeSource: return anchorVolumeId == nil ? .all : .volume
            case .document, .collection, .decimalClass: return .all
            }
        }

        /// `reconstructedAliasFallback`: the record's lot and names a Sources row carries, or none.
        var aliasFallback: IndexingPipeline.CollectionAliasFallback? {
            guard case .volumeSource(_, _, _, _, _, _, let aliasLot, let aliasNames, _) = self else { return nil }
            guard aliasLot != nil || !aliasNames.isEmpty else { return nil }
            return .init(lotFileNorm: aliasLot, names: aliasNames)
        }
    }

    /// The request a query names: a document by its volume and id, with the year it was opened with; a collection
    /// of the authority by its id; or an archival source by its keys, anchored on a volume or not, a class alone.
    static func neighborsRequest(_ query: FormQuery, resources: ServerResources) throws -> NeighborsRequest {
        func value(_ name: String) throws -> String? {
            guard let raw = try query.single(name) else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.utf8.count <= 1_024 else { throw APIProblem.invalidParameter(name, "is longer than 1,024 bytes") }
            return trimmed.isEmpty ? nil : trimmed
        }
        if let volumeId = try value("volumeId") {
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            guard let documentId = try value("documentId"), documentId.utf8.count <= 256, FRUSURLScheme.isSafeComponent(documentId) else {
                throw APIProblem.invalidParameter("documentId", "a document's neighbours need its id")
            }
            return .document(volumeId: volumeId, documentId: documentId, documentYear: try query.optionalInteger("year", in: 1_000...3_000))
        }
        if let id = try value("collection") {
            guard let record = try resources.collectionAuthorityRecord(id) else {
                throw APIProblem(.notFound, code: "COLLECTION_NOT_FOUND", detail: "The collection authority has no record \(id).")
            }
            return .collection(lotFileNorm: record.lotFileNorm, repository: record.repository, recordGroup: record.recordGroup,
                               names: [record.name] + record.aliases)
        }
        let lotFile = try value("lotFile"), recordGroup = try value("recordGroup"), series = try value("series")
        let repository = try value("repository"), decimalClass = try value("decimalClass"), jobNumber = try value("jobNumber")
        let aliasLot = try value("aliasLot")
        let aliasNames = (try query.list("aliasName") ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard aliasNames.count <= maximumAliases else {
            throw APIProblem.invalidParameter("aliasName", "names \(aliasNames.count) aliases, more than \(maximumAliases)")
        }
        var anchor: String?
        if let named = try value("anchor") {
            guard resources.volume(named) != nil else { throw APIProblem.volumeNotFound(named) }
            anchor = named
        }
        guard lotFile != nil || recordGroup != nil || series != nil || repository != nil || decimalClass != nil || jobNumber != nil else {
            throw APIProblem.invalidParameter("volumeId", "name a document, a collection or an archival source's keys")
        }
        if let decimalClass, lotFile == nil, recordGroup == nil, series == nil, repository == nil, jobNumber == nil,
           aliasLot == nil, aliasNames.isEmpty, anchor == nil {
            return .decimalClass(decimalClass)
        }
        return .volumeSource(lotFile: lotFile, recordGroup: recordGroup, series: series, repository: repository,
                             decimalClass: decimalClass, jobNumber: jobNumber, aliasLotFileNorm: aliasLot,
                             aliasNames: aliasNames, anchorVolumeId: anchor)
    }

    /// `ArchivalNeighborsRequest.load(appState:scopeVolumeIds:)`: the kit's query for the request, over the volumes
    /// the scope names, or all of them; a query that fails lists none, as the app's `try?` does.
    static func load(_ request: NeighborsRequest, scopeVolumeIds: Set<String>?,
                     pipeline: IndexingPipeline) async -> (documents: [IndexingPipeline.RelatedDocument], totalCount: Int, basis: String?) {
        switch request {
        case .document(let volumeId, let documentId, let documentYear):
            return (try? await pipeline.archivalNeighbors(
                forVolumeId: volumeId, documentId: documentId, documentYear: documentYear,
                scopeVolumeIds: scopeVolumeIds)) ?? ([], 0, nil)
        case .volumeSource(let lotFile, let recordGroup, let series, let repository, let decimalClass, let jobNumber, _, _, _):
            return (try? await pipeline.archivalNeighbors(
                forLotFile: lotFile, recordGroup: recordGroup, series: series, repository: repository,
                decimalClass: decimalClass, jobNumber: jobNumber, aliasFallback: request.aliasFallback,
                scopeVolumeIds: scopeVolumeIds)) ?? ([], 0, nil)
        case .collection(let lotFileNorm, let repository, let recordGroup, let names):
            return (try? await pipeline.collectionNeighbors(
                lotFileNorm: lotFileNorm, repository: repository, recordGroup: recordGroup, names: names,
                scopeVolumeIds: scopeVolumeIds)) ?? ([], 0, nil)
        case .decimalClass(let cls):
            return (try? await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: nil, repository: nil, decimalClass: cls,
                scopeVolumeIds: scopeVolumeIds)) ?? ([], 0, nil)
        }
    }
}

extension ServerResources {
    /// The collection authority's record `id`, decoding the authority off the cooperative pool on first use; nil for
    /// an id it does not hold, and for an authority missing or malformed.
    func collectionAuthorityRecord(_ id: String) throws -> AuthorityCollectionRecord? {
        guard id.utf8.count <= 1_024 else { throw APIProblem.invalidParameter("collection", "is longer than 1,024 bytes") }
        return collectionAuthority?.record(id: id)
    }
}
