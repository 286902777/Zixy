import Foundation

enum ZixyHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum ZixyAPIError: LocalizedError {
    case invalidURL
    case invalidBody
    case invalidResponse
    case requestFailed
    case server(statusCode: Int, message: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .invalidBody:
            return "The request data is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .requestFailed:
            return "Unable to connect to the server."
        case .server(let statusCode, let message):
            return message ?? "The request failed with status code \(statusCode)."
        case .decodingFailed:
            return "The server response could not be read."
        }
    }
}

final class ZixyAPIClient {

    static let shared = ZixyAPIClient(
        baseURL: URL(string: "https://opi.832cdqtw.link/")!
    )

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func request<Response: Decodable>(
        _ path: String,
        method: ZixyHTTPMethod = .get,
        query: [String: String] = [:],
        body: (any Encodable)? = nil,
        headers: [String: String] = [:]
    ) async throws -> Response {
        let responseData = try await data(
            path,
            method: method,
            query: query,
            body: body,
            headers: headers
        )

        do {
            return try decoder.decode(Response.self, from: responseData)
        } catch {
            throw ZixyAPIError.decodingFailed
        }
    }

    func data(
        _ path: String,
        method: ZixyHTTPMethod = .get,
        query: [String: String] = [:],
        body: (any Encodable)? = nil,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let urlRequest = try makeRequest(
            path: path,
            method: method,
            query: query,
            body: body,
            headers: headers
        )

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: urlRequest)
        } catch {
            throw ZixyAPIError.requestFailed
        }

        guard let response = result.1 as? HTTPURLResponse else {
            throw ZixyAPIError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ZixyAPIError.server(
                statusCode: response.statusCode,
                message: serverMessage(from: result.0)
            )
        }

        return result.0
    }

    private func makeRequest(
        path: String,
        method: ZixyHTTPMethod,
        query: [String: String],
        body: (any Encodable)?,
        headers: [String: String]
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: resolvedURL(for: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw ZixyAPIError.invalidURL
        }

        if !query.isEmpty {
            let items = query
                .sorted { $0.key < $1.key }
                .map(URLQueryItem.init(name:value:))
            components.queryItems = (components.queryItems ?? []) + items
        }

        guard let url = components.url else {
            throw ZixyAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body {
            request.httpBody = try encryptedBody(from: body)
        }

        return request
    }

    private func resolvedURL(for path: String) -> URL {
        let value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL ?? baseURL
    }

    private func encryptedBody(from body: any Encodable) throws -> Data {
        do {
            let jsonData = try encoder.encode(body)
            let json = String(decoding: jsonData, as: UTF8.self)
            let encrypted = try ZixyPayloadCipher.encrypt(json)
            return Data(encrypted.utf8)
        } catch {
            throw ZixyAPIError.invalidBody
        }
    }

    private func serverMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            return nil
        }

        return object["message"] as? String ?? object["error"] as? String
    }
}
