//
//  NetworkService.swift
//  Sphir
//
//  Thin async/await HTTP client for the Sphir API. Injects JSON + auth
//  headers, decodes into Decodable types, and signals a 401 by clearing the
//  Keychain and posting `.sphirUnauthorized` (AuthSession listens for it).
//

import Foundation

extension Notification.Name {
    /// Posted when the API returns 401; observers should sign the user out.
    static let sphirUnauthorized = Notification.Name("SphirUnauthorized")
}

enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case invalidCredentials
    case server(status: Int, body: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid request URL."
        case .unauthorized:          return "Your session expired. Please sign in again."
        case .invalidCredentials:    return "Incorrect email or password."
        case .server(let status, _): return "The server returned an error (\(status))."
        case .decoding:              return "Couldn't read the server's response."
        case .transport:             return "Couldn't reach Sphir. Check your connection."
        }
    }
}

/// Type-erased Encodable so callers can pass any request body.
struct AnyEncodable: Encodable {
    private let encodeTo: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeTo = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeTo(encoder) }
}

/// Use as the response type for endpoints that return no meaningful body.
struct EmptyResponse: Decodable {}

final class NetworkService {
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    static let shared = NetworkService(allowsNetwork: !NetworkService.isRunningTests)

    let baseURL: URL = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("LOCAL_API") {
            return URL(string: "http://localhost:3000")!
        }
        #endif
        // Pilot backend: SphirAPIBaseURL in Info.plist. The fallback is the pilot API too,
        // never production (api.sphir.io).
        if let value = Bundle.main.object(forInfoDictionaryKey: "SphirAPIBaseURL") as? String,
           !value.isEmpty, let url = URL(string: value) {
            return url
        }
        return URL(string: "https://sphir-api.onrender.com")!
    }()
    private let session: URLSession
    private let allowsNetwork: Bool
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    /// Where `.sphirUnauthorized` is posted; tests pass their own center.
    private let notificationCenter: NotificationCenter

    init(session: URLSession = .shared, allowsNetwork: Bool = true,
         notificationCenter: NotificationCenter = .default) {
        self.session = session
        self.allowsNetwork = allowsNetwork
        self.notificationCenter = notificationCenter
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    /// Perform a request and decode the JSON body into `T`.
    @discardableResult
    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        query: [String: String] = [:],
        body: Encodable? = nil,
        authorized: Bool = true
    ) async throws -> T {
        guard allowsNetwork else {
            throw NetworkError.transport(URLError(.notConnectedToInternet))
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://sphir.io",  forHTTPHeaderField: "Origin")
        request.setValue("https://sphir.io/", forHTTPHeaderField: "Referer")

        if authorized {
            // Authorization: Bearer <access_token>  +  uid: <uid>
            for (header, value) in KeychainService.authHeaders {
                request.setValue(value, forHTTPHeaderField: header)
            }
        }

        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        #if DEBUG
        // Never print request or response bodies: they carry passwords and tokens.
        print("[NET] \(method.rawValue) \(url.path)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.server(status: -1, body: nil)
        }

        #if DEBUG
        print("[NET] Status: \(http.statusCode)")
        #endif

        if http.statusCode == 401 {
            if authorized {
                KeychainService.clear()
                notificationCenter.post(name: .sphirUnauthorized, object: nil)
                throw NetworkError.unauthorized
            } else {
                throw NetworkError.invalidCredentials
            }
        }

        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.server(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }

        // Endpoints with no body (e.g. sign-out, delete).
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }
}

extension NetworkService {
    /// GET /api/v1/preview?url=… (S8). Usable from the app and SphirShare.
    func preview(url: String) async throws -> LinkPreview {
        try await request("/api/v1/preview", query: ["url": url])
    }

    /// POST /api/v1/preview {url, html} with the page Safari already loaded.
    /// Without HTML, or when the POST is rejected (older API without POST,
    /// body too large, …), uses GET. 401 and network errors are not retried.
    func preview(url: String, html: String?) async throws -> LinkPreview {
        guard let html, !html.isEmpty else { return try await preview(url: url) }
        do {
            return try await request("/api/v1/preview", method: .post,
                                     body: PreviewHTMLRequest(url: url, html: html))
        } catch NetworkError.server {
            return try await preview(url: url)
        }
    }
}

private struct PreviewHTMLRequest: Encodable {
    let url: String
    let html: String
}
