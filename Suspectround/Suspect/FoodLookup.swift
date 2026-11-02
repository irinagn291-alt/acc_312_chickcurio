import Foundation
import Observation

enum FoodLookupError: Error {
    case missing
    case failed
    case badPayload
}

/// One client for search and product-by-code. A miss falls back to the local shelf.
enum FoodLookup {
    static let userAgent = "ChickCurio/1.0 (iOS; +https://suspectround-hunt.site)"

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    static func search(terms: String) async throws -> [String] {
        let trimmed = terms.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "page_size", value: "8"),
            URLQueryItem(name: "fields", value: "product_name")
        ]
        guard let url = components.url else { throw FoodLookupError.failed }
        let data = try await load(url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        let envelope = try decoder.decode(SearchEnvelope.self, from: data)
        var names: [String] = []
        for product in envelope.products ?? [] {
            let name = product.product_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard name.isEmpty == false else { continue }
            guard names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) == false else { continue }
            names.append(name)
        }
        return names
    }

    static func productName(for code: String) async -> String? {
        let digits = RetailCode.candidates(in: code).first ?? code
        guard digits.isEmpty == false,
              let encoded = digits.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(encoded).json") else {
            return nil
        }
        do {
            let data = try await load(url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            let payload = try decoder.decode(ProductEnvelope.self, from: data)
            if payload.status == 0 { return nil }
            let name = payload.product?.product_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? nil : name
        } catch {
            return nil
        }
    }

    private static func load(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        do {
            return try await send(request)
        } catch let error as URLError where transient(error) {
            return try await send(request)
        }
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FoodLookupError.failed }
        if http.statusCode == 404 { throw FoodLookupError.missing }
        if (200..<300).contains(http.statusCode) {
            return data
        }
        if (500..<600).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        throw FoodLookupError.failed
    }

    private static func transient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost,
             .dnsLookupFailed, .notConnectedToInternet, .badServerResponse:
            return true
        default:
            return false
        }
    }
}

private struct SearchEnvelope: Decodable {
    struct Product: Decodable {
        var product_name: String?
    }

    var products: [Product]?
}

private struct ProductEnvelope: Decodable {
    struct Product: Decodable {
        var product_name: String?
    }

    var status: Int?
    var product: Product?
}

enum FoodShelf {
    static func names(books: [String]) -> [String] {
        var seen: [String] = []
        func add(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return }
            guard seen.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) == false else { return }
            seen.append(trimmed)
        }
        ["Oat milk", "Wheat bread", "Almond butter", "Soy yogurt"].forEach(add)
        #if targetEnvironment(simulator)
        ["Rice cakes", "Cow milk"].forEach(add)
        #endif
        books.forEach(add)
        return seen
    }
}

/// Debounced catalog query. Cancels the previous search when the text changes.
@MainActor
@Observable
final class NameDraft {
    var text = ""
    var hits: [String] = []
    var note: String?
    private var task: Task<Void, Never>?

    func schedule() {
        task?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            hits = []
            note = nil
            return
        }
        task = Task { [query] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard Task.isCancelled == false else { return }
            await self.apply(query)
        }
    }

    func apply(code: String) {
        task?.cancel()
        task = Task {
            let named = await FoodLookup.productName(for: code)
            guard Task.isCancelled == false else { return }
            text = named ?? code
            await apply(text)
        }
    }

    /// Runs search.pl before the caller writes a typed name. Empty and failed searches keep the typed words.
    func resolveForCommit() async -> String {
        task?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return "" }
        await apply(query)
        return hits.first ?? query
    }

    private func apply(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            hits = []
            note = nil
            return
        }
        do {
            let found = try await FoodLookup.search(terms: trimmed)
            guard Task.isCancelled == false else { return }
            hits = found
            note = found.isEmpty ? "No match. Pick from the shelf." : nil
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            guard Task.isCancelled == false else { return }
            hits = []
            note = "Search failed. Pick from the shelf."
        }
    }
}
