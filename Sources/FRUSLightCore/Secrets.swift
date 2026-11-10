// The keys the server keeps for the outside services it calls (PLAN's S20c), a user's Zotero and NARA
// Catalog keys and the instance's NARA key, as the Mac keeps them in the Keychain: sealed with AES-GCM
// under a key file the server makes at its first start, `/data/app/secret.key`, or the one
// `FRUS_SECRET_KEY_FILE` names. The store keeps each one sealed (`UserSecrets.swift`); this file is the
// key file, how a secret is sealed and opened, and the vault a route reads one through. Nothing here
// writes a secret, or the key, into an error, a log line or an answer.
//
// How one is sealed, format 1:
//   - a salt of 32 random bytes, new for each write;
//   - a key for that write alone, HKDF-SHA256 over the key file's 32 bytes with that salt, its `info`
//     the secret's binding: a label, whose it is (the instance's, or a user's by their id) and its name;
//   - a nonce of 12 random bytes, new for each write;
//   - AES-256-GCM over the secret, authenticating the same binding, so that a row copied to another
//     user, or to another name, does not open.
// What the store keeps is one byte for the format, then the salt, the nonce, the ciphertext and the
// tag. A key file is named, in the store and in a backup's manifest, by an id derived from it by HKDF
// under a label of its own, which says nothing of the key.

import Crypto
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// The keys the server keeps, by the names its API gives them.
public enum SecretName: String, Sendable, CaseIterable, Codable {
    /// A NARA Catalog API key, a user's own or the instance's.
    case nara
    /// A user's Zotero API key.
    case zotero

    /// The keys an owner may keep, in the order the app's Connections lists the services: a user both,
    /// the instance a NARA key alone, which serves everyone who has none of their own.
    public static func names(for owner: SecretOwner) -> [SecretName] {
        switch owner {
        case .user: [.nara, .zotero]
        case .instance: [.nara]
        }
    }
}

/// What a key may be: what a service's site gives to paste, trimmed of the spaces and line breaks a
/// paste brings, as the app trims one, and then 1 to 1,024 visible ASCII characters. A key goes out in
/// a request's header, so nothing that could end one, a line break among them, is ever kept.
public enum SecretValues {
    public static let longest = 1_024

    /// `value` trimmed, or why it is no key. The reason never repeats the value.
    public static func checked(_ value: String) -> Result<String, SecretValueProblem> {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure(SecretValueProblem(reason: "A key cannot be empty.")) }
        if trimmed.utf8.count > longest {
            return .failure(SecretValueProblem(reason: "A key may be at most \(longest) characters long."))
        }
        guard trimmed.utf8.allSatisfy({ (0x21...0x7e).contains($0) }) else {
            return .failure(SecretValueProblem(reason: "A key holds letters, digits and punctuation alone, with no spaces: paste it as the service gave it."))
        }
        return .success(trimmed)
    }
}

public struct SecretValueProblem: Error, Equatable, CustomStringConvertible {
    public let reason: String
    public var description: String { reason }
}

/// Whose a secret is and what it is called, as the bytes its sealing is bound to: a label for this use
/// and format, then the owner and the name, each field's length before it, so that no two bindings
/// are the same bytes.
struct SecretBinding {
    let owner: SecretOwner
    let name: String

    var bytes: [UInt8] {
        func field(_ text: String) -> [UInt8] {
            let utf8 = Array(text.utf8)
            return withUnsafeBytes(of: UInt32(utf8.count).bigEndian) { Array($0) } + utf8
        }
        var bytes = Array("frus-light/secret/v1".utf8) + [0]
        switch owner {
        case .instance: bytes += [0] + field("")
        case .user(let id): bytes += [1] + field(id)
        }
        return bytes + field(name)
    }
}

/// Why a kept secret could not be read. Neither names what it holds.
public enum SecretError: Error, Equatable, CustomStringConvertible {
    /// It was sealed under another key file than the server's.
    case sealedUnderAnotherKey(name: String, keyID: String)
    /// It does not open: its bytes, its owner or its name are not those it was sealed with.
    case doesNotOpen(name: String)

    public var description: String {
        switch self {
        case .sealedUnderAnotherKey(let name, let keyID):
            "The stored \(name) key was sealed under another key file (id \(keyID)) than this server's, so it cannot be read."
        case .doesNotOpen(let name):
            "The stored \(name) key does not open: the row is not as it was sealed."
        }
    }
}

/// The key the stored keys are sealed under: the 32 bytes of the key file.
public struct SecretKey: Sendable {
    public static let byteCount = 32
    /// What `seal` writes first, and the only format `open` reads.
    static let format: UInt8 = 1
    static let saltCount = 32
    static let nonceCount = 12
    static let tagCount = 16

    private let material: SymmetricKey
    /// Names the key file without giving anything of it away: 8 bytes derived from it by HKDF under a
    /// label of their own, in hexadecimal. The store keeps it beside each secret, and a backup's
    /// manifest lists it.
    public let id: String

    /// The key of a key file's bytes; nil unless they are 32.
    public init?(_ bytes: [UInt8]) {
        guard bytes.count == Self.byteCount else { return nil }
        self.init(material: SymmetricKey(data: bytes))
    }

    private init(material: SymmetricKey) {
        self.material = material
        let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: material, info: Array("frus-light/secret-key-id/v1".utf8),
                                             outputByteCount: 8)
        id = derived.withUnsafeBytes { $0.map { String(format: "%02x", $0) }.joined() }
    }

    /// A new key, from the system's generator.
    static func random() -> SecretKey {
        SecretKey(material: SymmetricKey(size: .bits256))
    }

    /// The key's bytes, for the key file alone.
    var bytes: [UInt8] { material.withUnsafeBytes { Array($0) } }

    /// The key one write is sealed under: derived from the key file with the write's salt, for the
    /// secret's binding alone.
    private func key(salt: some DataProtocol, for binding: [UInt8]) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: material, salt: salt, info: binding, outputByteCount: 32)
    }

    /// Seals `secret` as `binding`'s, with a salt and a nonce of this write's own, each from the
    /// system's generator.
    func seal(_ secret: [UInt8], for binding: SecretBinding) throws -> [UInt8] {
        try seal(secret, for: binding, salt: Self.random(Self.saltCount), nonce: Self.random(Self.nonceCount))
    }

    /// The same with the write's salt and nonce given, which only `seal(_:for:)` and a test that holds
    /// the bytes to a reference answer give.
    func seal(_ secret: [UInt8], for binding: SecretBinding, salt: [UInt8], nonce: [UInt8]) throws -> [UInt8] {
        precondition(salt.count == Self.saltCount && nonce.count == Self.nonceCount)
        let bound = binding.bytes
        let box = try AES.GCM.seal(secret, using: key(salt: salt, for: bound), nonce: AES.GCM.Nonce(data: nonce), authenticating: bound)
        return [Self.format] + salt + nonce + Array(box.ciphertext) + Array(box.tag)
    }

    /// `count` random bytes, as swift-crypto draws a new key's.
    private static func random(_ count: Int) -> [UInt8] {
        SymmetricKey(size: SymmetricKeySize(bitCount: count * 8)).withUnsafeBytes { Array($0) }
    }

    /// Opens what `seal` wrote for `binding`; nil for anything else: another format, another key file,
    /// another owner or name, or bytes changed since.
    func open(_ sealed: [UInt8], for binding: SecretBinding) -> [UInt8]? {
        let head = 1 + Self.saltCount + Self.nonceCount
        guard sealed.count >= head + Self.tagCount, sealed[0] == Self.format else { return nil }
        let salt = sealed[1..<1 + Self.saltCount]
        let nonce = sealed[1 + Self.saltCount..<head]
        let ciphertext = sealed[head..<sealed.count - Self.tagCount]
        let tag = sealed[(sealed.count - Self.tagCount)...]
        let bound = binding.bytes
        guard let box = try? AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: Array(nonce)), ciphertext: Array(ciphertext), tag: Array(tag)),
              let secret = try? AES.GCM.open(box, using: key(salt: Array(salt), for: bound), authenticating: bound) else { return nil }
        return Array(secret)
    }
}

/// Why a server could not start with its key file. Each is a sentence the install guide gives
/// (docs/INSTALL.md, The key file), with what to do.
public enum SecretKeyProblem: Error, Equatable, CustomStringConvertible {
    /// The store holds secrets, and the key file the server made is gone.
    case missing(path: String, secrets: Int)
    /// `FRUS_SECRET_KEY_FILE` names a file that is not there.
    case namedFileMissing(path: String)
    /// The key file is there and is not 32 bytes.
    case wrongSize(path: String, bytes: Int)
    case unreadable(path: String, reason: String)
    /// The store holds secrets sealed under another key file than the one that is there.
    case anotherKey(path: String, id: String, secrets: Int, sealedUnder: [String])
    case cannotMake(path: String, reason: String)
    /// The store is a PostgreSQL database, which every server sharing it opens, and no key file is named:
    /// each server would make a key file of its own, and none could open another's keys.
    case postgreSQLNeedsNamedFile

    /// How the guide and the sentences below say to forget what a key file in place does not open, with
    /// the server stopped; and every stored key, when no key file is left.
    public static let forget = "docker compose run --rm frus secrets forget"
    public static let forgetAll = "docker compose run --rm frus secrets forget --all"

    public var description: String {
        switch self {
        case .missing(let path, let secrets):
            return "the user store holds \(Self.keys(secrets)), and the key file that opens them, \(path), is missing. Put the key file back there, from the copy you kept, and start again. If no copy is left, run \(Self.forgetAll), which removes them so that the server makes a new key file, and the people who had stored a key enter it again in Settings ▸ Keys."
        case .namedFileMissing(let path):
            return "FRUS_SECRET_KEY_FILE names \(path), and there is no file there. Mount the key file at that path, 32 random bytes, or leave the variable out, and the server makes one in its data directory."
        case .wrongSize(let path, let bytes):
            return "the key file \(path) holds \(bytes) bytes, where a key file is 32 random bytes: it is not one, or was cut short. Put the key file there as it was made."
        case .unreadable(let path, let reason):
            return "the key file \(path) cannot be read: \(reason)."
        case .anotherKey(let path, let id, let secrets, let sealedUnder):
            return "the user store holds \(Self.keys(secrets)) that the key file \(path) does not open: \(secrets == 1 ? "it was" : "they were") sealed under another key file, id \(sealedUnder.joined(separator: ", ")), and this one's id is \(id). Put the key file \(secrets == 1 ? "it was" : "they were") sealed under there and start again. If it is lost, run \(Self.forget), which removes \(secrets == 1 ? "it" : "them"), and the people who had stored a key enter it again in Settings ▸ Keys."
        case .cannotMake(let path, let reason):
            return "the key file \(path) could not be made: \(reason). Make one yourself, 32 random bytes that only the server's user can read, at that path or at one FRUS_SECRET_KEY_FILE names."
        case .postgreSQLNeedsNamedFile:
            return "the user store is a PostgreSQL database, which every server that shares it opens, so each needs the same key file for the stored keys, and FRUS_SECRET_KEY_FILE names none. Make one, 32 random bytes, give it to each server as a secret is mounted, readable by the server's user alone, and name it there by its whole path."
        }
    }

    private static func keys(_ count: Int) -> String { count == 1 ? "1 stored key" : "\(count) stored keys" }
}

/// The key file: 32 random bytes, which the server makes at its first start, readable by its own user
/// alone, unless `FRUS_SECRET_KEY_FILE` names one, as a mounted secret is named.
public enum SecretKeyFile {
    /// The key in the file at `url`, or nil when there is no file there. A file that is not 32 bytes,
    /// or cannot be read, is a `SecretKeyProblem`.
    public static func key(at url: URL) throws -> SecretKey? {
        // Without waiting, as a FIFO's open would for a writer: what is not a file is refused below.
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else {
            if errno == ENOENT { return nil }
            throw SecretKeyProblem.unreadable(path: url.path, reason: String(cString: strerror(errno)))
        }
        defer { close(descriptor) }
        var status = stat()
        guard fstat(descriptor, &status) == 0 else {
            throw SecretKeyProblem.unreadable(path: url.path, reason: String(cString: strerror(errno)))
        }
        guard status.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw SecretKeyProblem.unreadable(path: url.path, reason: "it is not a file")
        }
        // One byte more than a key is asked for, so that a longer file is not read as its first 32.
        var bytes = [UInt8](repeating: 0, count: SecretKey.byteCount + 1)
        var count = 0
        while count < bytes.count {
            let got = bytes.withUnsafeMutableBytes { read(descriptor, $0.baseAddress! + count, $0.count - count) }
            if got < 0 {
                if errno == EINTR { continue }
                throw SecretKeyProblem.unreadable(path: url.path, reason: String(cString: strerror(errno)))
            }
            if got == 0 { break }
            count += got
        }
        guard let key = SecretKey(Array(bytes[..<count])) else {
            throw SecretKeyProblem.wrongSize(path: url.path, bytes: max(Int(status.st_size), count))
        }
        return key
    }

    /// Makes a key file at `url`, unless one is there, and returns the key the file then holds: the new
    /// one, or the one that was made first. The key is written whole to a file of its own beside it,
    /// which only the server's user can read, and that file is then linked under the key file's name.
    /// A link is made only where nothing has the name, and gives the name the whole file at once: of
    /// two servers that start together one makes the key and the other reads it, and neither ever reads
    /// part of one.
    public static func make(at url: URL) throws -> SecretKey {
        func problem(_ reason: String) -> SecretKeyProblem { .cannotMake(path: url.path, reason: reason) }
        func failure() -> SecretKeyProblem { problem(String(cString: strerror(errno))) }
        let staged = url.path + "." + UUID().uuidString + ".new"
        let descriptor = open(staged, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw failure() }
        defer { unlink(staged) }
        do {
            defer { close(descriptor) }
            let bytes = SecretKey.random().bytes
            var written = 0
            while written < bytes.count {
                let put = bytes.withUnsafeBytes { write(descriptor, $0.baseAddress! + written, $0.count - written) }
                if put < 0 {
                    if errno == EINTR { continue }
                    throw failure()
                }
                written += put
            }
            guard fsync(descriptor) == 0 else { throw failure() }
        }
        if link(staged, url.path) != 0, errno != EEXIST { throw failure() }
        // The name is kept through a loss of power, where the folder can be flushed.
        let folder = open(url.deletingLastPathComponent().path, O_RDONLY | O_CLOEXEC)
        if folder >= 0 {
            _ = fsync(folder)
            close(folder)
        }
        guard let key = try key(at: url) else { throw problem("it was removed as it was made") }
        return key
    }
}

/// The server's stored keys: what a route sets, clears and reads one through. A key is checked and
/// sealed before the store sees it, and opened only here, for the server's own use: no route gives one
/// back.
public struct SecretVault: Sendable {
    /// The key file's key, and where the file is.
    public let key: SecretKey
    public let keyFile: URL
    private let store: any SecretStore

    public init(key: SecretKey, keyFile: URL, store: any SecretStore) {
        self.key = key
        self.keyFile = keyFile
        self.store = store
    }

    /// How a start came by its key.
    public enum KeyOrigin: Sendable, Equatable {
        /// The key file was there.
        case found
        /// There was none, and no stored key that one would open, so the server made it.
        case made
    }

    /// The vault a server starts with, over the key file at `keyFile`: the one `FRUS_SECRET_KEY_FILE`
    /// names, when `named`, or the server's own in its data directory, which it makes when it is not
    /// there. It refuses, with a `SecretKeyProblem`, a named file that is missing, since a server makes
    /// only its own; its own file missing while the store holds stored keys, which a new key file would
    /// never open; a key file that does not open the keys the store holds; and, for a store that
    /// `shared` servers open, as a PostgreSQL store is, a key file that is not named, since each would
    /// make its own.
    public static func open(store: any SecretStore, keyFile: URL, named: Bool, shared: Bool = false) throws -> (vault: SecretVault, origin: KeyOrigin) {
        guard named || !shared else { throw SecretKeyProblem.postgreSQLNeedsNamedFile }
        let counts = try store.secretCounts()
        guard let key = try SecretKeyFile.key(at: keyFile) else {
            if named { throw SecretKeyProblem.namedFileMissing(path: keyFile.path) }
            let secrets = counts.values.reduce(0, +)
            guard secrets == 0 else { throw SecretKeyProblem.missing(path: keyFile.path, secrets: secrets) }
            return (SecretVault(key: try SecretKeyFile.make(at: keyFile), keyFile: keyFile, store: store), .made)
        }
        let others = counts.filter { $0.key != key.id }
        guard others.isEmpty else {
            throw SecretKeyProblem.anotherKey(path: keyFile.path, id: key.id, secrets: others.values.reduce(0, +),
                                              sealedUnder: others.keys.sorted())
        }
        return (SecretVault(key: key, keyFile: keyFile, store: store), .found)
    }

    /// Keeps `value` as `owner`'s key `name`, in place of any they had: trimmed and held to
    /// `SecretValues`' rule, which throws a `SecretValueProblem`, then sealed.
    @discardableResult
    public func set(_ value: String, named name: SecretName, for owner: SecretOwner, at time: Date) throws -> SecretEntry {
        let checked = try SecretValues.checked(value).get()
        let sealed = try key.seal(Array(checked.utf8), for: SecretBinding(owner: owner, name: name.rawValue))
        return try store.setSecret(sealed, keyID: key.id, named: name.rawValue, of: owner, at: time)
    }

    /// `owner`'s key `name`, opened, for a request the server itself makes with it; nil when they have
    /// none. One that this key file does not open is a `SecretError`.
    public func value(named name: SecretName, for owner: SecretOwner) throws -> String? {
        guard let kept = try store.sealedSecret(named: name.rawValue, of: owner) else { return nil }
        guard kept.keyID == key.id else { throw SecretError.sealedUnderAnotherKey(name: name.rawValue, keyID: kept.keyID) }
        guard let secret = key.open(kept.sealed, for: SecretBinding(owner: owner, name: name.rawValue)) else {
            throw SecretError.doesNotOpen(name: name.rawValue)
        }
        return String(decoding: secret, as: UTF8.self)
    }

    /// Removes `owner`'s key `name`; false when they had none.
    @discardableResult
    public func remove(named name: SecretName, for owner: SecretOwner) throws -> Bool {
        try store.removeSecret(named: name.rawValue, of: owner)
    }

    /// When each key `owner` may keep was last set, for those that are; nothing of what any holds.
    public func entries(for owner: SecretOwner) throws -> [SecretName: Date] {
        var entries: [SecretName: Date] = [:]
        for entry in try store.secretEntries(of: owner) {
            if let name = SecretName(rawValue: entry.name), SecretName.names(for: owner).contains(name) {
                entries[name] = entry.updatedAt
            }
        }
        return entries
    }
}
