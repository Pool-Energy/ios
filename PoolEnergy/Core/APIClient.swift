import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case http(Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .http(let code):
            if code == 429 {
                return "Too many requests — the public API is rate limited, try again in a few minutes."
            }
            return "The API answered with HTTP \(code)"
        case .decoding(let error):
            return "Unexpected response format"
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

struct APIClient {
    static let shared = APIClient()

    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "https://pool.energy/api/v1.0/")!) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }

    // MARK: Public

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await request(url(for: path, query: query))
    }

    func page<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> Page<T> {
        try await request(url(for: path, query: query))
    }

    func page<T: Decodable>(from urlString: String) async throws -> Page<T> {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        return try await request(url)
    }

    // MARK: Private

    private func url(for path: String, query: [String: String]) -> URL {
        let base = baseURL.absoluteString + path
        guard var components = URLComponents(string: base) else { return baseURL }
        if !query.isEmpty {
            components.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url ?? baseURL
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
