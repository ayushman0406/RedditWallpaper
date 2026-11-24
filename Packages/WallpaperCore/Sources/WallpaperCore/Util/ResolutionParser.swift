import Foundation

/// Reads image sizes that Reddit wallpaper posts put in their titles,
/// e.g. "Vestrahorn [3840x2160]" or "Lake Bled (2560 × 1440)".
public enum ResolutionParser {
    /// Two 3–5 digit numbers separated by x, X or ×, spaces allowed.
    private static let sizePattern = #"(\d{3,5})\s*[xX×]\s*(\d{3,5})"#
    private static let sizeRegex = try? NSRegularExpression(pattern: sizePattern)

    public static func resolution(in title: String) -> (width: Int, height: Int)? {
        guard let regex = sizeRegex else { return nil }
        let range = NSRange(title.startIndex..., in: title)
        guard let match = regex.firstMatch(in: title, range: range),
              let widthRange = Range(match.range(at: 1), in: title),
              let heightRange = Range(match.range(at: 2), in: title),
              let width = Int(title[widthRange]),
              let height = Int(title[heightRange]),
              width >= 320, height >= 240 else {
            return nil
        }
        return (width, height)
    }

    /// Removes size tags and "[OC]" markers so the title reads like a name.
    public static func cleanTitle(_ title: String) -> String {
        let removals = [
            #"[\[\(]\s*\d{3,5}\s*[xX×]\s*\d{3,5}\s*[\]\)]"#,
            #"[\[\(]\s*OC\s*[\]\)]"#,
            sizePattern,
        ]
        var result = title
        for pattern in removals {
            result = result.replacingOccurrences(
                of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        result = result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–|,:"))
        return result.trimmingCharacters(in: trimSet)
    }
}
