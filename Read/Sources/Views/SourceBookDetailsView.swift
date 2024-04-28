//
//  SourceBookDetailsView.swift
//  Read
//
//  Created by Mirna Olvera on 3/31/24.
//

import SwiftUI

struct SourceBookDetailsView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(SourceManager.self) private var sourceManager
    @State var extensionJS: SourceExtension?

    @State private var bookDetails: SourceBook?
    @State private var loadingState: Bool = false

    var sourceId: String
    var item: PartialSourceBook

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom, spacing: 10) {
                    SourceBookImage(imageUrl: bookDetails?.bookInfo.image ?? item.image)
                        .frame(width: 114, height: 114 * 1.5)
                        .clipShape(.rect(cornerRadius: 6))

                    VStack(alignment: .leading) {
                        Text(bookDetails?.bookInfo.title ?? item.title)
                            .font(.system(size: 22, weight: .semibold))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(bookDetails?.bookInfo.author ?? item.author ?? "Unknown Author")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let desc = bookDetails?.bookInfo.desc {
                    MoreText(text: desc)
                        .tint(theme.tintColor)
                }

                if loadingState == false, let bookDetails {
                    SourceDownloadButton(
                        book: bookDetails
                    )

                } else {
                    Button {} label: {
                        HStack(spacing: 8) {
                            Text(loadingState ? "loading..." : "not available")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 32)
                    .disabled(true)
                    .clipShape(.rect(cornerRadius: 10))
                    .buttonStyle(.borderedProminent)
                }

                if let tags = bookDetails?.bookInfo.tags {
                    TagScrollView(tags: tags)
                }
            }
            .scenePadding()
        }
        .transition(.opacity)
        .animation(.snappy, value: loadingState)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if loadingState == true {
                    ProgressView()
                }
            }
        }
        .task {
            self.loadingState = true
            self.extensionJS = sourceManager.extensions[sourceId]

            guard let extensionJS = extensionJS else {
                loadingState = false
                return
            }

            if extensionJS.loaded == false {
                _ = extensionJS.initialiseSource()
            }

            do {
                let details = try await extensionJS.getBookDetails(for: item.id)

                bookDetails = details
            } catch {
                // TODO: ERROR
                Log("Something went wrong getting book details: \(error.localizedDescription)")
            }

            loadingState = false
        }
    }
}

#Preview {
    SourceBookDetailsView(sourceId: "", item: PartialSourceBook(id: "", title: ""))
}
