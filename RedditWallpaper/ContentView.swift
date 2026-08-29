import SwiftUI

struct ContentView: View {
    @State private var wallpapers: [RedditPost] = []
    @State private var isFetching = false
    @State private var errorMessage: String?
    @State private var downloadingPost: RedditPost?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Reddit Wallpaper")
                    .font(.headline)
                Spacer()
                Button(action: fetchNewBatch) {
                    if isFetching {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isFetching)
                .buttonStyle(PlainButtonStyle())
                .padding(4)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(4)
            }
            .padding()
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            
            Divider()
            
            // Wallpapers Grid/List
            if wallpapers.isEmpty && !isFetching {
                VStack {
                    Spacer()
                    Text("Click refresh to load wallpapers.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 300)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(wallpapers, id: \.self) { post in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                                
                                ZStack(alignment: .bottomTrailing) {
                                    AsyncImage(url: URL(string: post.url)) { phase in
                                        switch phase {
                                        case .empty:
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 140)
                                                .overlay(ProgressView())
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 140)
                                                .clipped()
                                        case .failure:
                                            Rectangle()
                                                .fill(Color.red.opacity(0.2))
                                                .frame(height: 140)
                                                .overlay(Text("Failed to load image").font(.caption))
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .cornerRadius(8)
                                    
                                    Button(action: { setWallpaper(post) }) {
                                        HStack(spacing: 4) {
                                            if downloadingPost == post {
                                                ProgressView()
                                                    .scaleEffect(0.5)
                                                    .frame(width: 12, height: 12)
                                            }
                                            Text(downloadingPost == post ? "Setting..." : "Set as Wallpaper")
                                                .font(.caption)
                                                .bold()
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.7))
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(downloadingPost != nil)
                                    .padding(8)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .frame(height: 450)
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        }
        .frame(width: 320)
        .onAppear {
            if wallpapers.isEmpty {
                fetchNewBatch()
            }
        }
    }
    
    private func fetchNewBatch() {
        isFetching = true
        errorMessage = nil
        
        Task {
            do {
                let posts = try await RedditFetcher.fetchRandomWallpapers(count: 10)
                wallpapers = posts
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
            }
            isFetching = false
        }
    }
    
    private func setWallpaper(_ post: RedditPost) {
        downloadingPost = post
        errorMessage = nil
        
        Task {
            do {
                try await WallpaperManager.shared.downloadAndSet(post: post)
            } catch {
                errorMessage = "Failed to set wallpaper: \(error.localizedDescription)"
            }
            downloadingPost = nil
        }
    }
}
