import Foundation

/// Reads image sizes that Reddit wallpaper posts put in their titles,
/// e.g. "Vestrahorn [3840x2160]".
public enum ResolutionParser {
    public static func resolution(in title: String) -> (width: Int, height: Int)? {
        nil
    }

    public static func cleanTitle(_ title: String) -> String {
        title
    }
}
