// A stored summary as the app shows it (FRUS-Explorer#1822 and #1824, at the pin since the move to
// `fe9325b2`): a structured summary's fields, labelled, where every surface showed the JSON the model
// gave, and any other summary's text as it is stored. The fields are the kit's
// `StructuredSummaryDisplay`, over the summary's `ResponseFormat` as the store keeps it, the JSON the
// kit's encoder writes; a value it cannot decode, which the app's model never holds, is taken as
// `.general`, whose text shows as stored.
//
// App code mirrored here, held to its source by NotesAndSummariesParityTests:
// - `GeneratedSummary.plainReaderText(separator:)` and `indexedText`, in
//   `FRUSExplorer/Summarization/StructuredSummaryText.swift`: the kit's plain text of the summary, the
//   text the app's index holds for it, inserts into a note and opens a headnote's Edit on.

import FRUSCoreKit
import Foundation

/// How a stored summary reads: its fields, and its plain text.
public enum SummaryDisplay {
    /// The kit's `ResponseFormat` of a stored value, `.general` for one it cannot read.
    public static func format(_ stored: String) -> ResponseFormat {
        (try? JSONDecoder().decode(ResponseFormat.self, from: Data(stored.utf8))) ?? .general
    }

    /// `StructuredSummaryDisplay.fields(responseText:format:)`: a structured summary's fields in its
    /// schema's order, each labelled, or nil for a plain summary and for text that is no JSON object
    /// of strings.
    public static func fields(_ summary: SummaryRecord) -> [StructuredSummaryDisplay.Field]? {
        StructuredSummaryDisplay.fields(responseText: summary.responseText, format: format(summary.responseFormat))
    }

    /// `GeneratedSummary.plainReaderText(separator:)`: a structured summary's fields each as
    /// *Label: text*, joined by `separator`, a blank line unless one is given, or the stored text.
    public static func plainText(_ summary: SummaryRecord, separator: String = "\n\n") -> String {
        StructuredSummaryDisplay.plainText(responseText: summary.responseText, format: format(summary.responseFormat),
                                           separator: separator)
    }
}
