import SwiftUI

/// A remote (or local) image that fills its frame, with quiet loading and
/// failure states. Callers set the frame and clip it.
struct ThumbnailView: View {
    let url: URL
    var placeholder: URL? = nil

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "photo").font(.title2).foregroundStyle(.tertiary)
                }
            default:
                if let placeholder {
                    ThumbnailView(url: placeholder)
                } else {
                    Rectangle().fill(.quaternary).overlay { ProgressView().controlSize(.small) }
                }
            }
        }
    }
}
