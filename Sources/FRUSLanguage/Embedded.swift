// The model and the lists this module carries (PLAN's S29c), compiled into it as two generated files,
// `EmbeddedModel.swift` and `EmbeddedWordNet.swift`, which `frus-language` writes, so that the server's
// binary holds them and reads them in the hardened image with nothing beside it. Each is held to the
// length and SHA-256 its file records when it is read.

import Foundation

/// Why the embedded model or lists could not be read.
struct EmbeddedDataError: Error, CustomStringConvertible {
    let description: String
}

extension EmbeddedModel {
    /// The model's file, held to its recorded length and SHA-256.
    static func bytes() throws -> [UInt8] {
        let text = base64.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
        guard let data = Data(base64Encoded: text, options: .ignoreUnknownCharacters) else {
            throw EmbeddedDataError(description: "the model's base64 does not decode")
        }
        let bytes = [UInt8](data)
        guard bytes.count == byteCount, LanguageTagger.sha256(bytes) == sha256 else {
            throw EmbeddedDataError(description: "the model is \(bytes.count) bytes at \(LanguageTagger.sha256(bytes)), where its file records \(byteCount) at \(sha256)")
        }
        return bytes
    }
}

extension EmbeddedWordNet {
    /// The lists' canonical text, held to its recorded SHA-256.
    static func canonicalText() throws -> String {
        let text = lists.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
        let digest = LanguageTagger.sha256(Array(text.utf8))
        guard digest == sha256 else {
            throw EmbeddedDataError(description: "the lists' digest is \(digest), where their file records \(sha256)")
        }
        return text
    }
}

/// What the module carries, for a report: the model's and the lists' provenance as their files record it.
public enum LanguageData {
    /// The model's provenance: its training text, its settings and its counts.
    public static var modelProvenance: String { EmbeddedModel.provenance }
    /// The lists' provenance: WordNet's release and where it came from.
    public static var listsProvenance: String { EmbeddedWordNet.provenance }
}
