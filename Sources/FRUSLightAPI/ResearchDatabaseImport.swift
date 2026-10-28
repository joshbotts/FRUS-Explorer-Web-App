// An export made with the owner's writing (PLAN's S16e), the API's half: Import mode's importer is
// given the kit's strip, `ResearchDatabaseStrip.steps`, which it runs as the app's export runs them,
// and the user store the writing goes into, for the user an import from the drop zone acts for.

import FRUSCoreKit
import FRUSLightCore

enum ResearchDatabaseImport {
    /// The kit's statements, in their order.
    static let strip = ResearchDatabaseStrip.steps.map { StripStep(action: $0.action, sql: $0.sql) }

    /// The move into `store`, for its single user, the one `FRUS_AUTH=none` acts for, who is the one
    /// who copies an export into the drop zone. Each summary takes the kit's `ResponseFormat.general`,
    /// since the index keeps no summary's format.
    static func move(into store: some ResearchDatabaseWritingStore & UserStore) -> WritingMove {
        WritingMove(strip: strip) { writing in
            try store.keep(writing, summaryFormat: Summary.generalFormat, for: try store.singleUserID())
        }
    }
}
