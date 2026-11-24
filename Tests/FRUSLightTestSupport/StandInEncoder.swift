// The encoder's stand-in for the tests (PLAN's S27b): Tests/EncoderStandIn, built beside each test runner,
// which answers as llama.cpp's llama-server does with vectors of its own; a "model" for it, a file of its
// settings, and the SearchModel that names that file's digest, as the bundled index names the real one's.

import FRUSLightCore
import Foundation

public enum StandInEncoder {
    /// The stand-in's binary: the executable product `EncoderStandIn`, which SwiftPM builds beside the test
    /// runner, since the test targets that start it depend on it.
    public static func binary() throws -> URL {
        var folders: [URL] = []
        if let runner = Bundle.main.executableURL { folders.append(runner.resolvingSymlinksInPath().deletingLastPathComponent()) }
        folders.append(URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent())
        if let link = try? FileManager.default.destinationOfSymbolicLink(atPath: "/proc/self/exe") {
            folders.append(URL(fileURLWithPath: link).deletingLastPathComponent())
        }
        for folder in folders {
            let candidate = folder.appendingPathComponent("EncoderStandIn")
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        throw StandInMissing(folders: folders.map(\.path))
    }

    public struct StandInMissing: Error, CustomStringConvertible {
        public let folders: [String]
        public var description: String {
            "the encoder's stand-in, EncoderStandIn, is not built beside the test runner (looked in \(folders.joined(separator: ", "))): build the package's products first"
        }
    }

    /// A model for the stand-in in `directory`: a file of its settings, and the SearchModel naming its
    /// digest, as the bundled index names the real model's.
    public static func model(in directory: URL, dimensions: Int = 768, loadMilliseconds: Int = 0, failStart: Bool = false,
                             name: String = "stand-in.gguf") throws -> (url: URL, model: SearchModel) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data(#"{"dimensions":\#(dimensions),"loadMilliseconds":\#(loadMilliseconds),"failStart":\#(failStart)}"#.utf8).write(to: url)
        return (url, SearchModel(name: "stand-in", sha256: try SearchModel.digest(of: url), dimensions: dimensions))
    }

    /// The encoder's settings over the stand-in and a model of it in `directory`, with an idle window of
    /// `idle`, short for a test that waits it out.
    public static func settings(in directory: URL, enabled: Bool = true, idle: Duration = .seconds(180),
                                loadMilliseconds: Int = 0, failStart: Bool = false) throws -> EncoderSettings {
        let (url, model) = try model(in: directory, loadMilliseconds: loadMilliseconds, failStart: failStart)
        return EncoderSettings(enabled: enabled, binary: try binary(), model: url, bundled: model, idleTimeout: idle,
                               startTimeout: .seconds(60), queryTimeout: .seconds(30), stopTimeout: .seconds(5))
    }

    /// The stand-in's vector of `content`, unnormalised, as it computes it (Tests/EncoderStandIn): each value
    /// a function of the content's FNV-1a hash and its place, in single precision.
    public static func vector(_ content: String, dimensions: Int = 768) -> [Double] {
        var seed: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in content.utf8 { seed = (seed ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
        return (0..<dimensions).map { place in
            let bits = Double((seed >> UInt64(place % 48)) & 0xffff) / 65_536.0 - 0.5
            return Double(Float(bits * Double(1 + place % 5)))
        }
    }

    /// The stand-in's count of `prompt`'s tokens: one a word, and the model's two special tokens.
    public static func tokens(_ prompt: String) -> Int {
        prompt.split(whereSeparator: \.isWhitespace).count + 2
    }
}
