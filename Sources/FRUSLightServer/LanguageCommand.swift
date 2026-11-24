// `frus-light language-selftest` (PLAN's S29c): tags the web tagger's fixed text with the model and lists
// compiled into the binary, and prints the family's identity and the SHA-256 of what came of it, which the
// smoke test holds to the digest committed in fixtures/language/selftest.sha256 on each architecture. It
// reads no configuration and no file, so it runs as it is in the hardened image.
//   docker compose exec frus frus-light language-selftest [--expect <sha256>]

import FRUSLanguage
import Foundation

enum LanguageCommand {
    /// Prints the report, and exits 0, or with `--expect`, 0 when the digest is the one expected and 1 when
    /// it is not; 2 for any other argument.
    static func selftest(_ arguments: [String], say: (String) -> Void = { print($0) }) -> Int32 {
        var expected: String?
        var rest = arguments[...]
        while let argument = rest.popFirst() {
            guard argument == "--expect", let value = rest.popFirst(), expected == nil else {
                FileHandle.standardError.write(Data("usage: frus-light language-selftest [--expect <sha256>]\n".utf8))
                return 2
            }
            expected = value
        }
        let tagger = LanguageTagger.shared
        let lines = LanguageSelftest.lines(tagger)
        let digest = LanguageSelftest.digest(tagger)
        say("Language self-test")
        func row(_ label: String, _ value: String) { say("  \(label.padding(toLength: 8, withPad: " ", startingAt: 0))  \(value)") }
        row("Family", "\(tagger.identity), which names no one")
        row("Model", "SHA-256 \(tagger.identity.modelSHA256): \(tagger.model.tags.count) tags, \(tagger.model.featureCount) features")
        row("Lists", "SHA-256 \(tagger.identity.listsSHA256): WordNet 3.0's exceptions and lemmas")
        row("Words", "\(lines.count - 1) of the fixed text, tagged and lemmatized")
        row("Digest", digest)
        guard let expected else { return 0 }
        if digest == expected {
            row("Expected", "the same")
            return 0
        }
        row("Expected", "\(expected): this binary tags the fixed text otherwise")
        return 1
    }
}
