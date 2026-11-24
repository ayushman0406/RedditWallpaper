import Foundation

enum Fixture {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}

/// Decoded query items of a request, keyed by name.
func queryItems(_ request: URLRequest) -> [String: String] {
    guard let url = request.url,
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [:] }
    var result: [String: String] = [:]
    for item in components.queryItems ?? [] {
        result[item.name] = item.value ?? ""
    }
    return result
}
