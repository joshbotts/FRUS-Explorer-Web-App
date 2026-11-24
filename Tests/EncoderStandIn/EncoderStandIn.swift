// A stand-in for llama.cpp's llama-server (PLAN's S27b), which the swift job's tests start as the server's
// encoder, since the job has neither CMake nor the model. It answers as llama-server does where the server's
// encoder asks: it takes the command line the server gives the real one, refusing an argument it does not
// know, as llama-server does; listens on 127.0.0.1 alone; refuses every request but the health check without
// the start's key, LLAMA_API_KEY; answers /health 503 while it "loads" and 200 after; and answers /tokenize
// and /embedding in llama-server's shapes, a query past its physical batch refused in llama-server's words.
// Its vectors are its own: each value a function of the content's FNV-1a hash and its place, unnormalised,
// which QueryEncoderTests computes again. Its "model" is a JSON file of settings a test writes:
//   {"dimensions": 768, "loadMilliseconds": 200, "failStart": false}

import Foundation
import Hummingbird
import NIOCore

@main
struct EncoderStandIn {
    struct Settings: Decodable {
        var dimensions = 768
        var loadMilliseconds = 0
        var failStart = false
    }

    static func main() async throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--version"] {
            // llama-server writes its version to standard error.
            FileHandle.standardError.write(Data("version: 0.0.0-stand-in (build 1, commit 5ea4d11)\nbuilt with a stand-in\n".utf8))
            return
        }
        var modelPath: String?
        var host = "127.0.0.1"
        var port = 8080
        var batch = 512
        let valued: Set<String> = ["--model", "--host", "--port", "--ctx-size", "--batch-size", "--ubatch-size", "--parallel", "--fit", "--log-colors"]
        let flags: Set<String> = ["--embedding", "--no-warmup", "--no-webui", "--no-slots"]
        while !arguments.isEmpty {
            let argument = arguments.removeFirst()
            if flags.contains(argument) { continue }
            guard valued.contains(argument), let value = arguments.first else { fail("error: invalid argument: \(argument)") }
            arguments.removeFirst()
            switch argument {
            case "--model": modelPath = value
            case "--host": host = value
            case "--port": port = Int(value) ?? 0
            case "--ubatch-size": batch = Int(value) ?? batch
            default: break
            }
        }
        guard host == "127.0.0.1" else { fail("stand-in: asked to listen on \(host), not 127.0.0.1 alone") }
        guard let model = modelPath, let data = FileManager.default.contents(atPath: model) else {
            fail("error: failed to load model '\(modelPath ?? "")'")
        }
        let settings: Settings
        do {
            settings = try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            fail("error: failed to load model '\(model)': \(error)")
        }
        guard let key = ProcessInfo.processInfo.environment["LLAMA_API_KEY"], !key.isEmpty else {
            fail("stand-in: started with no LLAMA_API_KEY, which the server's encoder always gives")
        }
        if settings.failStart { fail("stand-in: failing to start, as its model asks") }
        say("stand-in: loading \(model) for \(settings.loadMilliseconds) ms, batch \(batch)")
        let loaded = ContinuousClock.now + .milliseconds(settings.loadMilliseconds)
        let physicalBatch = batch

        let router = Router()
        router.add(middleware: KeyCheck(key: key))
        router.get("/health") { _, _ -> Response in
            if ContinuousClock.now < loaded {
                return json(503, #"{"error":{"code":503,"message":"Loading model","type":"unavailable_error"}}"#)
            }
            return json(200, #"{"status":"ok"}"#)
        }
        router.post("/tokenize") { request, context -> Response in
            struct Body: Decodable {
                let content: String
                let add_special: Bool?
                let parse_special: Bool?
            }
            let body = try await request.decode(as: Body.self, context: context)
            let tokens = Self.tokens(body.content, special: body.add_special ?? false)
            return json(200, #"{"tokens":["# + tokens.map(String.init).joined(separator: ",") + "]}")
        }
        router.post("/embedding") { request, context -> Response in
            struct Body: Decodable {
                let content: String
                let embd_normalize: Int?
            }
            let body = try await request.decode(as: Body.self, context: context)
            let count = Self.tokens(body.content, special: true).count
            guard count <= physicalBatch else {
                return json(500, #"{"error":{"code":500,"message":"input (\#(count) tokens) is too large to process. increase the physical batch size (current batch size: \#(physicalBatch))","type":"server_error"}}"#)
            }
            var values = vector(body.content, dimensions: settings.dimensions)
            if (body.embd_normalize ?? 2) == 2 {
                // llama-server's own normalisation, in single precision, which the server's encoder never asks for.
                let norm = Float(values.reduce(0.0) { $0 + Double($1) * Double($1) }.squareRoot())
                values = values.map { $0 / norm }
            }
            let text = values.map { String(Double($0)) }.joined(separator: ",")
            return json(200, #"[{"index":0,"embedding":[["# + text + "]]}]")
        }
        let app = Application(router: router, configuration: .init(address: .hostname("127.0.0.1", port: port), serverName: "stand-in"))
        say("stand-in: server is listening on http://127.0.0.1:\(port)")
        try await app.runService()
    }

    /// The stand-in's tokens: one a word, and the model's two special tokens when asked for.
    static func tokens(_ content: String, special: Bool) -> [Int] {
        let words = content.split(whereSeparator: \.isWhitespace).map { $0.utf8.count + 3 }
        return special ? [2] + words + [1] : words
    }

    static func say(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    static func fail(_ line: String) -> Never {
        say(line)
        exit(1)
    }
}

/// The stand-in's vector of `content`: each value a function of the content's FNV-1a hash and its place, in
/// single precision, as a model's are, and of no particular length. QueryEncoderTests computes it again.
func vector(_ content: String, dimensions: Int) -> [Float] {
    var seed: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in content.utf8 { seed = (seed ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
    return (0..<dimensions).map { place in
        let bits = Double((seed >> UInt64(place % 48)) & 0xffff) / 65_536.0 - 0.5
        return Float(bits * Double(1 + place % 5))
    }
}

func json(_ status: Int, _ body: String) -> Response {
    Response(status: .init(code: status), headers: [.contentType: "application/json; charset=utf-8"],
             body: .init(byteBuffer: ByteBuffer(string: body)))
}

/// llama-server's key check: every request but the health check carries `Authorization: Bearer <key>`.
struct KeyCheck<Context: RequestContext>: RouterMiddleware {
    let key: String

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        if request.uri.path == "/health" || request.headers[.authorization] == "Bearer \(key)" {
            return try await next(request, context)
        }
        return json(401, #"{"error":{"message":"Invalid API Key","type":"authentication_error","code":401}}"#)
    }
}
