import Foundation
import Testing
@testable import WallpaperCore

@Suite struct RedditSourceTests {
    let source = RedditSource()
    let anime = InterestCatalog.preset(id: "anime")!
    let cars = InterestCatalog.preset(id: "cars")!

    @Test func requestUsesInterestSubreddit() throws {
        let query = SourceQuery(scope: .interest(anime), kind: .photo, sort: .top, page: 1)
        let request = try source.makeRequest(for: query)
        #expect(request.url?.absoluteString == "https://meme-api.com/gimme/Animewallpaper/30")
    }

    @Test func requestUsesPicksForGeneral() throws {
        let query = SourceQuery(scope: .general, kind: .photo, sort: .top, page: 2)
        #expect(try source.makeRequest(for: query).url?.absoluteString == "https://meme-api.com/gimme/wallpapers/30")
    }

    @Test func unsupportedForVideoAndOffTopicInterest() {
        #expect(!source.supports(SourceQuery(scope: .general, kind: .video, sort: .top)))
        #expect(!source.supports(SourceQuery(scope: .interest(cars), kind: .photo, sort: .top)))
        #expect(!source.supports(SourceQuery(scope: .search("cars"), kind: .photo, sort: .top)))
        #expect(source.supports(SourceQuery(scope: .interest(anime), kind: .photo, sort: .top)))
    }

    @Test func parsesFixture() throws {
        let query = SourceQuery(scope: .general, kind: .photo, sort: .new)
        let items = try source.parse(Fixture.data("memeapi-wallpaper"), for: query)
        #expect(items.map(\.id) == ["reddit:1xql8t2", "reddit:1xnqm4b", "reddit:1xutj60"])
        let vestrahorn = try #require(items.first { $0.id == "reddit:1xnqm4b" })
        #expect(vestrahorn.title == "Vestrahorn")
        #expect(vestrahorn.width == 3840)
        #expect(vestrahorn.height == 2160)
        #expect(vestrahorn.score == 273)
        #expect(vestrahorn.kind == .photo)
        #expect(vestrahorn.source == .reddit)
        #expect(vestrahorn.author == "u/ex_cep_tion")
        #expect(vestrahorn.mediaURL.absoluteString == "https://i.redd.it/nyzz8ji43mzh1.png")
        #expect(vestrahorn.thumbnailURL.absoluteString.contains("width=640"))
        #expect(vestrahorn.pageURL?.absoluteString == "https://redd.it/1xnqm4b")
    }

    @Test func dropsNSFWAndNonImages() throws {
        let json = """
        {"count":3,"memes":[
         {"postLink":"https://redd.it/a1","subreddit":"wallpaper","title":"Nope [1920x1080]","url":"https://i.redd.it/a1.jpg","nsfw":true,"spoiler":false,"author":"x","ups":5,"preview":[]},
         {"postLink":"https://redd.it/a2","subreddit":"wallpaper","title":"Gallery","url":"https://www.reddit.com/gallery/a2","nsfw":false,"spoiler":false,"author":"x","ups":5,"preview":[]},
         {"postLink":"https://redd.it/a3","subreddit":"wallpaper","title":"Fine [2560x1440]","url":"https://i.redd.it/a3.jpeg","nsfw":false,"author":"x","ups":5}
        ]}
        """
        let query = SourceQuery(scope: .general, kind: .photo, sort: .new)
        let items = try source.parse(Data(json.utf8), for: query)
        #expect(items.map(\.id) == ["reddit:a3"])
        #expect(items.first?.thumbnailURL.absoluteString == "https://i.redd.it/a3.jpeg")
    }

    @Test func topSortsByUpvotes() throws {
        let query = SourceQuery(scope: .general, kind: .photo, sort: .top)
        let items = try source.parse(Fixture.data("memeapi-wallpaper"), for: query)
        #expect(items.map(\.score) == [273, 29, 8])
    }

    @Test func errorMessageReadsMemeAPIMessage() throws {
        let message = source.errorMessage(status: 400, data: try Fixture.data("memeapi-error"))
        #expect(message == "r/carporn has no Posts with Images")
    }
}
