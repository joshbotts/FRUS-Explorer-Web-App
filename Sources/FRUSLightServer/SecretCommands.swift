// `frus-light secrets forget` (PLAN's S20c): removes the stored API keys the key file does not open,
// beside backup, restore and user. A server does not start while its store holds a stored key that its
// key file does not open, or while the key file it made is gone, since a new key file would leave
// those keys unreadable and say nothing; when the key file is lost for good, this is the way on. It
// runs with the server stopped, as a restore does. With a key file in place it removes the keys sealed
// under another and keeps the rest. With none in place it removes nothing, since a key file that is
// only not there, as one not yet mounted, is no key file lost, unless `--all` asks it to remove every
// stored key, after which the next start makes a new key file. A key file that FRUS_SECRET_KEY_FILE
// names must be there. Each person then enters theirs again in Settings ▸ Keys.
//   docker compose run --rm frus secrets forget [--all]

import FRUSLightCore
import Foundation

enum SecretCommands {
    static let usage = "usage: frus-light secrets forget [--all]"

    /// Runs `arguments`, the words after `secrets`. Exits 0 when it did what it says, 1 when it could not
    /// or would not, and 2 for other words.
    static func run(_ arguments: [String], _ configuration: ServerConfiguration, console: UserCommands.Console = .process) async -> Int32 {
        let all: Bool
        switch arguments {
        case ["forget"]: all = false
        case ["forget", "--all"]: all = true
        default:
            console.complain(usage)
            return 2
        }
        let named = configuration.secretKeyFile != nil
        let keyFile = configuration.secretKeyFile ?? DataDirectory(root: configuration.dataDirectory).secretKey
        let again = "The people who had stored one enter it again in Settings ▸ Keys."
        do {
            // The key file that is there, if one is: what it opens is kept. One that is no key file is
            // said, and nothing is removed, since it may be the right file cut short.
            let key = try SecretKeyFile.key(at: keyFile)
            if key == nil, named { throw UserCommands.Failure(message: "\(SecretKeyProblem.namedFileMissing(path: keyFile.path)) Nothing was forgotten.") }
            try await UserCommands.withStore(configuration, exclusive: true) { store in
                let held = try store.secretCounts().values.reduce(0, +)
                guard held > 0 else {
                    console.say("The store holds no stored keys, so none was forgotten.")
                    return
                }
                guard let key else {
                    guard all else {
                        throw UserCommands.Failure(message: "there is no key file at \(keyFile.path) to open the \(count(held)) the store holds, so nothing was forgotten. Put the key file back there if you kept a copy; if it is lost for good, run frus-light secrets forget --all, which removes every stored key, and the next start makes a new key file.")
                    }
                    let removed = try store.removeSecrets(notSealedUnder: nil)
                    console.say("Forgot the \(count(removed)) the store held, as --all asks: there is no key file at \(keyFile.path) to open \(removed == 1 ? "it" : "them"), and the next start makes one. \(again)")
                    return
                }
                if all {
                    let removed = try store.removeSecrets(notSealedUnder: nil)
                    console.say("Forgot every stored key, \(removed) of them, as --all asks; new ones are sealed under \(keyFile.path). \(again)")
                    return
                }
                let removed = try store.removeSecrets(notSealedUnder: key.id)
                console.say(removed == 0
                    ? "\(keyFile.path) opens every stored key the store holds, \(held) of them, so none was forgotten."
                    : "Forgot \(count(removed)) of the \(held) the store held, which \(keyFile.path) does not open. \(again)")
            }
            return 0
        } catch let failure as UserCommands.Failure {
            console.complain("frus-light: \(failure.message)")
            return failure.status
        } catch {
            console.complain("frus-light: \(error)")
            return 1
        }
    }

    private static func count(_ keys: Int) -> String { keys == 1 ? "1 stored key" : "\(keys) stored keys" }
}
