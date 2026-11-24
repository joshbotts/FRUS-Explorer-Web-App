// `frus-light language-selftest` (PLAN's S29c): the web tagger's self-test, which reads no configuration:
// its identity and digest printed, the committed digest accepted, any other refused, and any other argument a
// usage error. The digest itself is FRUSLanguageTests' and the smoke test's to hold.

import FRUSLanguage
import Foundation
import Testing

@testable import FRUSLightServer

@Suite struct LanguageCommandTests {
    static func run(_ arguments: [String]) -> (status: Int32, lines: [String]) {
        var lines: [String] = []
        let status = LanguageCommand.selftest(arguments) { lines.append($0) }
        return (status, lines)
    }

    @Test func itPrintsTheIdentityAndTheDigest() {
        let (status, lines) = Self.run([])
        let digest = LanguageSelftest.digest(LanguageTagger.shared)
        #expect(status == 0)
        #expect(lines.first == "Language self-test")
        #expect(lines.contains("  Family    \(LanguageTagger.shared.identity), which names no one"))
        #expect(lines.contains("  Digest    \(digest)"))
    }

    @Test func theExpectedDigestPassesAndAnotherFails() {
        let digest = LanguageSelftest.digest(LanguageTagger.shared)
        #expect(Self.run(["--expect", digest]).status == 0)
        let other = Self.run(["--expect", String(repeating: "0", count: 64)])
        #expect(other.status == 1)
        #expect(other.lines.last?.hasSuffix("this binary tags the fixed text otherwise") == true)
    }

    @Test func anyOtherArgumentIsAUsageError() {
        #expect(Self.run(["--expect"]).status == 2)
        #expect(Self.run(["--expect", "a", "--expect", "b"]).status == 2)
        #expect(Self.run(["now"]).status == 2)
    }
}
