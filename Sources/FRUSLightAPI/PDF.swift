// The server's PDF service as the browser app asks for it (PLAN's S25a). `GET /api/v1/pdf` says whether
// the service `FRUS_PDF_URL` names answers now, so that the export sheet offers PDF only while it does:
// none when the URL is unset, and none while compose.yaml's `pdf` profile is off, whose address the URL
// names all the same. A collection's PDF is its export's (CollectionExports.swift), and what goes wrong
// in making one is a problem in the sheet's words, here; an analytics figure's PDF waits for PLAN's S24f.

import FRUSLightCore
import Hummingbird

/// `GET /api/v1/pdf`: whether the export sheet offers PDF.
public struct PDFAvailability: Codable, Equatable, Sendable, ResponseEncodable {
    /// Whether the server's PDF service answers its health check now.
    public var available: Bool
}

enum PDFRoutes {
    static func add(to router: Router<APIRequestContext>, service: PDFService?) {
        // Never cached: the service may start or stop at any time, and the server asks it at most every
        // ten seconds (`PDFService.checkInterval`).
        router.get("/api/v1/pdf") { request, _ -> EditedResponse<PDFAvailability> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let available = await service?.isAvailable() ?? false
            return EditedResponse(headers: [.cacheControl: "no-store"], response: PDFAvailability(available: available))
        }
    }

    /// A service that does not answer now, as the sheet shows it.
    static let unavailable = APIProblem(
        .serviceUnavailable, code: "PDF_SERVICE_UNAVAILABLE",
        detail: "The server’s PDF service is not answering, so no PDF was made. Try again in a moment, or choose another format.")

    /// What the service's failure to make a PDF is to the browser: not answering, or too busy, as
    /// Gotenberg's 503 says a request that ran past its time limit is, a 503 the sheet can try again;
    /// any other failure the service's own, a 502, with its words.
    static func problem(_ error: PDFServiceError) -> APIProblem {
        switch error {
        case .unavailable, .refused(status: 503, _), .refused(status: 429, _):
            return unavailable
        case .refused, .badAnswer, .tooLarge:
            return APIProblem(.badGateway, code: "PDF_NOT_MADE",
                              detail: "The server’s PDF service could not make this PDF: \(error).")
        }
    }
}
