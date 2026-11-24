// `frus-light semantic` (PLAN's S27b): Administration ▸ Semantic's Search Model for a server whose
// Administration is refused, as one with FRUS_USER_DATA=off: the model in the image, its size and its
// SHA-256 held to the bundled index's, the engine, and the encoder's setting and state. The command is not
// the server, so it holds no encoder of its own: it reads the server's from the process table, loaded once
// its health answers.
//   docker compose exec frus frus-light semantic

import FRUSLightCore
import Foundation

enum SemanticCommand {
    /// Prints the report, and exits 0 when the server can search by meaning, or does not because
    /// FRUS_ENCODER is off; 1 when it is on and cannot.
    static func run(_ arguments: [String], _ configuration: ServerConfiguration,
                    say: (String) -> Void = { print($0) }) async -> Int32 {
        guard arguments.isEmpty else {
            FileHandle.standardError.write(Data("usage: frus-light semantic\n".utf8))
            return 2
        }
        var report = await QueryEncoder(settings: EncoderSettings(configuration: configuration)).report()
        if report.state == "idle",
           let running = QueryEncoder.runningProcesses(binary: configuration.encoderBinary, model: configuration.encoderModel).first {
            report.state = running.port.map { HealthCheck.isHealthy(port: $0, path: "/health") } == true ? "loaded" : "starting"
            report.pid = Int(running.pid)
            report.residentBytes = QueryEncoder.residentBytes(of: running.pid)
        }
        for line in lines(report) { say(line) }
        return report.state == "unavailable" ? 1 : 0
    }

    /// The report in lines, as the pane lays it out.
    static func lines(_ report: EncoderReport) -> [String] {
        let model = report.model
        var lines = ["Search Model"]
        func row(_ label: String, _ value: String) { lines.append("  \(label.padding(toLength: 10, withPad: " ", startingAt: 0))  \(value)") }
        row("Model", "\(model.name ?? model.file), Google's EmbeddingGemma 2, under \(model.licence): \(model.path)")
        if let bytes = model.bytes {
            row("Size", "\(grouped(bytes)) bytes, \(megabytes(bytes))" + (bytes == model.publishedBytes ? ", the length the app publishes" : ", where the app publishes \(grouped(model.publishedBytes))"))
        } else {
            row("Size", "not in the image")
        }
        switch model.verified {
        case true?: row("SHA-256", "\(model.sha256 ?? ""), the bundled index's: verified")
        case false?: row("SHA-256", "\(model.sha256 ?? ""), where the bundled index names \(model.bundledSHA256 ?? "none")")
        case nil: row("SHA-256", "not read; the bundled index names \(model.bundledSHA256 ?? "none")")
        }
        let engine = report.engine
        row("Engine", engine.present ? "llama.cpp's llama-server, \(engine.path)\(engine.commit.map { ", commit \($0)" } ?? "")" : "none at \(engine.path)")
        row("Encoder", encoderLine(report))
        if let problem = report.problem { row("Problem", problem) }
        return lines
    }

    static func encoderLine(_ report: EncoderReport) -> String {
        let memory = report.residentBytes.map { ", holding \(megabytes($0))" } ?? ""
        switch report.state {
        case "off": return "off (FRUS_ENCODER=off): it never starts, and the server offers no search by meaning"
        case "unavailable": return "on (FRUS_ENCODER), and it cannot start"
        case "starting": return "on: starting, process \(report.pid.map(String.init) ?? "")"
        case "loaded": return "on: loaded, process \(report.pid.map(String.init) ?? "")\(memory); it stops after \(report.idleSeconds / 60) minutes without a search"
        default: return "on: idle, it starts at the next search by meaning"
        }
    }

    static func grouped(_ count: Int) -> String {
        count.formatted(.number.locale(Locale(identifier: "en_US")))
    }

    static func megabytes(_ bytes: Int) -> String {
        "\(Int((Double(bytes) / 1_000_000).rounded())) MB"
    }
}
