import Foundation

struct MemeAPIResponse: Codable {
    let count: Int
    let memes: [RedditPost]
}

struct RedditPost: Codable, Hashable {
    let title: String
    let url: String
    let nsfw: Bool
}

class RedditFetcher {
    enum FetchError: Error {
        case invalidURL
        case noData
        case decodingError
        case noSuitableWallpapers
    }
    
    static func fetchRandomWallpapers(count: Int = 10) async throws -> [RedditPost] {
        // Fetch a bit more than requested in case some are filtered out
        guard let url = URL(string: "https://meme-api.com/gimme/wallpaper/\(count + 10)") else {
            throw FetchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("RedditWallpaperApp/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FetchError.noData
        }
        
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "MemeAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(body.prefix(100))"])
        }
        
        do {
            let decoded = try JSONDecoder().decode(MemeAPIResponse.self, from: data)
            
            // Filter out NSFW and ensure it's a valid image URL
            let validPosts = decoded.memes.filter { post in
                !post.nsfw &&
                (post.url.hasSuffix(".jpg") || post.url.hasSuffix(".png") || post.url.hasSuffix(".jpeg"))
            }
            
            // Return exactly the requested amount
            return Array(validPosts.prefix(count))
        } catch {
            print("Decoding error: \(error)")
            throw FetchError.decodingError
        }
    }
}
