// FRUS Explorer Light server. Configuration comes from FRUS_* environment variables (docs/SPEC.md).

import FRUSLightCore
import Foundation
import Hummingbird
import Logging

@main
struct FRUSLightServer {
    static func main() async throws {
        if CommandLine.arguments.contains("--version") {
            print("frus-light \(FRUSLightVersion.string)")
            return
        }
        let configuration: ServerConfiguration
        do {
            configuration = try ServerConfiguration.fromEnvironment()
        } catch {
            fail("\(error)", status: 2)
        }
        do {
            let app = try await buildApplication(configuration: configuration)
            try await app.runService()
        } catch {
            fail("\(error)", status: 1)
        }
    }

    static func fail(_ message: String, status: Int32) -> Never {
        FileHandle.standardError.write(Data("frus-light: \(message)\n".utf8))
        exit(status)
    }
}
