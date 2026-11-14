// The corrections a curator makes and their log (PLAN's S21g), migration 8, on both stores: a merge kept once
// either way round and never of a record with itself, a separation once, each undone by its id; a document's
// classification kept one per document and restored with FRUS's value; and each change an entry of the log, in
// the same transaction, naming who and when, waiting until the index takes it, newest first when read. Serialized:
// each PostgreSQL case holds two or three connections, and the target's cases at once can pass PostgreSQL's hundred.

import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite(.serialized) struct CorrectionLogTests {
    static let made = Date(timeIntervalSince1970: 1_794_700_000)  // 2026-11-14
    static let later = made.addingTimeInterval(60)
    static let adenauer = PersonRecordKey(volumeId: "frus1961-63v06", ref: "p_AK3")
    static let adzhubei = PersonRecordKey(volumeId: "frus1961-63v06", ref: "p_AAI1")
    static let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")

    @Test(arguments: UserStoreKind.available) func aMergeIsKeptOnceEitherWayRoundAndLogged(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let entry = try #require(try store.recordPersonMerge(Self.adenauer, Self.adzhubei, by: "owner", at: Self.made))
        #expect(entry.correction == .person && entry.action == .made && entry.kind == .merge)
        #expect(entry.volumeIdA == Self.adenauer.volumeId && entry.refA == "p_AK3" && entry.volumeIdB == Self.adzhubei.volumeId && entry.refB == "p_AAI1")
        let owner = try store.user("owner")?.displayName
        #expect(entry.userId == "owner" && entry.userName == owner && entry.madeAt == Self.made)
        #expect(entry.appliedAt == nil, "waiting for the index")
        let overrides = try store.personOverrides()
        #expect(overrides.map(\.id) == [entry.overrideId] && overrides.first?.createdAt == Self.made)
        #expect(overrides.first?.data == PersonClusterOverrideData(kind: .merge, volumeIdA: "frus1961-63v06", refA: "p_AK3",
                                                                    volumeIdB: "frus1961-63v06", refB: "p_AAI1"))
        #expect(try store.recordPersonMerge(Self.adzhubei, Self.adenauer, by: "owner", at: Self.later) == nil, "kept already, the other way round")
        #expect(throws: CorrectionStoreError.selfMerge) { try store.recordPersonMerge(Self.adenauer, Self.adenauer, by: "owner", at: Self.later) }
        #expect(try store.personOverrides().count == 1 && store.correctionLog(limit: 10).map(\.id) == [entry.id], "nothing written")
    }

    @Test(arguments: UserStoreKind.available) func aSeparationIsKeptOnceAndEachIsUndoneByItsId(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let merge = try #require(try store.recordPersonMerge(Self.adenauer, Self.adzhubei, by: "owner", at: Self.made))
        let split = try #require(try store.recordPersonSplit(Self.adzhubei, by: "owner", at: Self.later))
        #expect(split.kind == .split && split.refA == "p_AAI1" && split.volumeIdB == nil && split.refB == nil)
        #expect(try store.recordPersonSplit(Self.adzhubei, by: "owner", at: Self.later) == nil, "kept already")
        #expect(try store.personOverrides().map(\.kind) == [.split, .merge], "newest first, as the app's fetch gives them")
        let undone = try #require(try store.undoPersonCorrection(merge.overrideId, by: "owner", at: Self.later))
        #expect(undone.action == .undone && undone.overrideId == merge.overrideId && undone.kind == .merge && undone.refB == "p_AAI1")
        #expect(try store.personOverrides().map(\.id) == [split.overrideId])
        #expect(try store.undoPersonCorrection(merge.overrideId, by: "owner", at: Self.later) == nil, "gone already")
        #expect(try store.correctionLog(limit: 10).map(\.id) == [undone.id, split.id, merge.id], "newest first")
        #expect(try store.correctionLog(limit: 2).map(\.id) == [undone.id, split.id])
        #expect(try store.correctionLog(of: .person).count == 3 && store.correctionLog(of: .classification).isEmpty)
    }

    @Test(arguments: UserStoreKind.available) func aClassificationIsKeptOnePerDocumentAndRestored(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let correction = ClassificationOverride(volumeId: Self.d1.volumeId, documentId: Self.d1.documentId, isEditorialNote: true,
                                                parsedIsEditorialNote: false, createdAt: Self.made)
        let made = try store.recordClassification(correction, by: "owner", at: Self.made)
        #expect(made.correction == .classification && made.action == .made && made.overrideId == correction.id)
        #expect(made.document == Self.d1 && made.isEditorialNote == true && made.parsedIsEditorialNote == false)
        #expect(try store.classificationOverrides() == [correction])
        // `record`'s rule: a document's correction takes a new value and keeps its id and what the TEI said.
        let again = try store.recordClassification(
            ClassificationOverride(volumeId: Self.d1.volumeId, documentId: Self.d1.documentId, isEditorialNote: false,
                                   parsedIsEditorialNote: true, createdAt: Self.later), by: "owner", at: Self.later)
        #expect(again.overrideId == correction.id && again.parsedIsEditorialNote == false)
        #expect(try store.classificationOverrides().map(\.isEditorialNote) == [false])
        let restored = try #require(try store.undoClassification(of: Self.d1, restoring: false, by: "owner", at: Self.later))
        #expect(restored.action == .undone && restored.isEditorialNote == false && restored.overrideId == correction.id)
        #expect(try store.classificationOverrides().isEmpty)
        #expect(try store.undoClassification(of: Self.d1, restoring: false, by: "owner", at: Self.later) == nil, "none to undo")
        #expect(try store.correctionLog(of: Self.d1).map(\.id) == [restored.id, again.id, made.id])
    }

    @Test(arguments: UserStoreKind.available) func entriesWaitUntilTheIndexTakesThem(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let first = try #require(try store.recordPersonSplit(Self.adenauer, by: "owner", at: Self.made))
        let second = try store.recordClassification(
            ClassificationOverride(volumeId: Self.d1.volumeId, documentId: Self.d1.documentId, isEditorialNote: true,
                                   parsedIsEditorialNote: false), by: "owner", at: Self.later)
        #expect(try store.waitingCorrections().map(\.id) == [first.id, second.id], "in the order they were made")
        try store.markCorrectionsApplied([first.id], at: Self.later)
        #expect(try store.waitingCorrections().map(\.id) == [second.id])
        try store.markCorrectionsApplied([first.id, second.id], at: Self.later.addingTimeInterval(60))
        #expect(try store.waitingCorrections().isEmpty)
        let log = try store.correctionLog(limit: 10)
        #expect(log.first { $0.id == first.id }?.appliedAt == Self.later, "taken once, its time kept")
        #expect(log.first { $0.id == second.id }?.appliedAt == Self.later.addingTimeInterval(60))
    }

    /// What an export is given again at each install: a document whose correction was last undone here, and which holds
    /// none now; a later correction of it takes its place.
    @Test(arguments: UserStoreKind.available) func aRestoreStandsUntilTheDocumentIsCorrectedAgain(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        _ = try store.record(ClassificationOverride(volumeId: Self.d1.volumeId, documentId: Self.d1.documentId, isEditorialNote: true,
                                                    parsedIsEditorialNote: false))
        #expect(try store.standingRestores().isEmpty)
        let restored = try #require(try store.undoClassification(of: Self.d1, restoring: false, by: "owner", at: Self.made))
        #expect(try store.standingRestores().map(\.id) == [restored.id])
        _ = try store.recordClassification(
            ClassificationOverride(volumeId: Self.d1.volumeId, documentId: Self.d1.documentId, isEditorialNote: true,
                                   parsedIsEditorialNote: false), by: "owner", at: Self.later)
        #expect(try store.standingRestores().isEmpty, "corrected again")
        let again = try #require(try store.undoClassification(of: Self.d1, restoring: false, by: "owner", at: Self.later))
        #expect(try store.standingRestores().map(\.id) == [again.id], "the latest restore alone")
    }
}
