// FRUS Explorer Light server. Configuration comes from FRUS_* environment variables (docs/SPEC.md).

import FRUSLightAPI
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
        if CommandLine.arguments.contains("--check-health") {
            // Docker's HEALTHCHECK: the process answers on its own port.
            let raw = ProcessInfo.processInfo.environment["FRUS_PORT"]?.trimmingCharacters(in: .whitespaces)
            let port = raw.flatMap(Int.init) ?? 8080
            let status = HealthCheck.probe(port: port)
            print(status)
            exit(status.hasPrefix("HTTP/1.1 200") ? 0 : 1)
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
        } catch let error as ServerResourcesError {
            // A configuration problem, like those above: FRUS_RESOURCES_DIR names the wrong folder.
            fail("\(error)", status: 2)
        } catch {
            fail("\(error)", status: 1)
        }
    }

    static func fail(_ message: String, status: Int32) -> Never {
        FileHandle.standardError.write(Data("frus-light: \(message)\n".utf8))
        exit(status)
    }
}
