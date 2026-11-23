// Check 8's third export rule (PLAN's S25b): the kit's reading of a 1906–1910 file number, which both of the app's
// Source Explorer views take, asked through the kit's public calls. Since FRUS-Explorer#722 (for #354, "Never resolve a
// Numerical File roll for a decimal-era citation"), the kit reads no Numerical File case from a file number in the
// Decimal File's form, a point followed by a digit or a letter before its slash ("723.2515/110"), where the Source
// Explorer export generator's own core, which took no such rule, reads the digits before the point as a case and finds
// that case's rolls (FRUS-Explorer#1974, filed for the export to take the kit's rule). This file imports FRUSCoreKit,
// which shares names with the generator's cores, so that `SourceExplorerCheck`, which imports the cores, asks the kit
// through it alone.

import FRUSCoreKit
import Foundation

/// The kit's Numerical File over the bundled central-files index, as the server reads it.
public struct KitNumericalFile: Sendable {
    let index: NumericalFileIndex

    public init(resources: URL) throws {
        index = try JSONDecoder().decode(CentralFilesIndex.self,
                                         from: Data(contentsOf: resources.appendingPathComponent("central-files-index.json"))).numericalFile
    }

    /// The rolls, by NARA id, that the kit finds for a file number, as the app's views ask (`rolls(forFileNumber:)`).
    public func rolls(forFileNumber fileNumber: String) -> [String] {
        index.rolls(forFileNumber: fileNumber).map(\.naId)
    }

    /// Whether the kit reads no case from `fileNumber` for its Decimal File form alone: it finds no roll for the file
    /// number, and finds exactly `rolls` for the same number with its point, and what follows the point before the
    /// slash, taken out, the case the export's core reads from it.
    public func refusesDecimalForm(_ fileNumber: String, whereTheCaseFinds rolls: [String]) -> Bool {
        guard !rolls.isEmpty, self.rolls(forFileNumber: fileNumber).isEmpty,
              let point = fileNumber.firstIndex(of: ".") else { return false }
        let tail = fileNumber[point...].firstIndex(of: "/").map { String(fileNumber[$0...]) } ?? ""
        return self.rolls(forFileNumber: String(fileNumber[..<point]) + tail) == rolls
    }
}
