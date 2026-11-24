import Foundation

/// Builds URL query strings where only RFC 3986 unreserved characters stay
/// unescaped, so user text like "Tom & Jerry" or "C++" can't break a request
/// (URLComponents leaves "&" and "+" alone in values).
public enum QueryString {
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public static func encode(_ items: [(String, String)]) -> String {
        items.map { "\(escape($0.0))=\(escape($0.1))" }.joined(separator: "&")
    }

    static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }
}
