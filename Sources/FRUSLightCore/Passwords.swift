// Local accounts' passwords (PLAN's S20b): Argon2id, through the reference implementation Ubuntu
// packages (`CArgon2`). A hash is kept as the PHC string the library writes,
// `$argon2id$v=19$m=65536,t=3,p=4$<salt>$<tag>`, which carries its own costs and salt, so a password
// hashed under other costs still verifies. A password is normalized to NFKC first, as NIST SP 800-63B
// asks, so the same characters typed on another keyboard or system are the same password.

import CArgon2
import Foundation

/// Hashes and verifies local accounts' passwords with Argon2id.
public struct PasswordHasher: Sendable {
    /// Argon2id's costs: passes over the memory, the memory in KiB, and the lanes it is filled in.
    public struct Parameters: Sendable, Equatable {
        public var iterations: UInt32
        public var memoryKiB: UInt32
        public var lanes: UInt32

        public init(iterations: UInt32, memoryKiB: UInt32, lanes: UInt32) {
            self.iterations = iterations
            self.memoryKiB = memoryKiB
            self.lanes = lanes
        }

        /// RFC 9106's second recommended option, for a host with less memory than its first asks:
        /// three passes over 64 MiB in four lanes, with a 128-bit salt and a 256-bit tag.
        public static let standard = Parameters(iterations: 3, memoryKiB: 64 * 1_024, lanes: 4)
        /// The least the library takes: the tests', whose hashes need be no stronger than the code they test.
        public static let leastCost = Parameters(iterations: 1, memoryKiB: 8, lanes: 1)
    }

    public let parameters: Parameters

    /// The salt's length, 128 bits, and the tag's, 256 bits, as RFC 9106 recommends.
    static let saltLength = 16
    static let tagLength = 32

    public init(_ parameters: Parameters = .standard) {
        self.parameters = parameters
    }

    /// The PHC string of `password`'s hash, with a salt of its own.
    public func hash(_ password: String) throws -> String {
        var generator = SystemRandomNumberGenerator()
        return try hash(password, salt: (0..<Self.saltLength).map { _ in generator.next() })
    }

    /// The same with the salt given: a known answer's, in the tests.
    func hash(_ password: String, salt: [UInt8]) throws -> String {
        let bytes = Array(Self.normalized(password).utf8)
        let costs = parameters
        var encoded = [CChar](repeating: 0, count: argon2_encodedlen(costs.iterations, costs.memoryKiB, costs.lanes,
                                                                         UInt32(salt.count), UInt32(Self.tagLength), Argon2_id))
        let length = encoded.count
        let status = bytes.withUnsafeBytes { password in
            salt.withUnsafeBytes { salt in
                encoded.withUnsafeMutableBufferPointer { output in
                    argon2id_hash_encoded(costs.iterations, costs.memoryKiB, costs.lanes, password.baseAddress, password.count,
                                          salt.baseAddress, salt.count, Self.tagLength, output.baseAddress, length)
                }
            }
        }
        guard status == Int32(ARGON2_OK.rawValue) else { throw PasswordHashError(status: status) }
        return String(decoding: encoded.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Whether `password` is the one `encoded`, a PHC string `hash(_:)` wrote, was made from. The
    /// library compares the two tags in a time that does not depend on where they differ, and a
    /// string that is no Argon2id hash verifies nothing.
    public func verify(_ password: String, against encoded: String) -> Bool {
        let bytes = Array(Self.normalized(password).utf8)
        let status = encoded.withCString { encoded in
            bytes.withUnsafeBytes { password in argon2id_verify(encoded, password.baseAddress, password.count) }
        }
        return status == Int32(ARGON2_OK.rawValue)
    }

    /// A hash of no one's password under these costs: what a sign-in for a name with no password is
    /// verified against, so that it takes the time one with a password takes.
    public func decoy() throws -> String {
        var generator = SystemRandomNumberGenerator()
        return try hash((0..<32).map { _ in String(format: "%02x", generator.next() as UInt8) }.joined())
    }

    /// `password` in NFKC, the form it is hashed in.
    static func normalized(_ password: String) -> String {
        password.precomposedStringWithCompatibilityMapping
    }
}

/// The library refused to hash: its own words for why.
public struct PasswordHashError: Error, CustomStringConvertible {
    public let status: Int32

    public var description: String {
        "Argon2 could not hash the password: \(String(cString: argon2_error_message(status)))"
    }
}

/// What a new password must be (PLAN's S20b): at least fifteen characters, as NIST SP 800-63B-4 asks
/// of a password that is the only factor, counted as it is hashed, each code point of its NFKC form
/// one character; at most 1,024 bytes of UTF-8, which bounds what a sign-in hashes; and no control
/// characters, which a terminal or a form could not give back as they were set. Every other character,
/// spaces among them, is allowed, and no rule asks for a mix of kinds.
public enum PasswordRules {
    public static let shortest = 15
    public static let longest = 1_024

    /// Why `password` cannot be set, in a sentence, or nil when it can.
    public static func problem(with password: String) -> String? {
        let normalized = PasswordHasher.normalized(password)
        if normalized.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) {
            return "A password may not hold a control character, such as a tab or a line break."
        }
        if normalized.unicodeScalars.count < shortest {
            return "A password must be at least \(shortest) characters long; a phrase of a few words is one."
        }
        if normalized.utf8.count > longest {
            return "A password may be at most \(longest) bytes long."
        }
        return nil
    }
}
