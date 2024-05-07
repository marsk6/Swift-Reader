//
//  Navigator.swift
//  Read
//
//  Created by Mirna Olvera on 4/13/24.
//

import Foundation
import SwiftUI

public enum NavigatorDestination: Hashable {
    case localDetails(book: Book)
    case downloadManager

    case sourceSearch(search: String)
    case source(sourceUrl: URL)
    case sourceSettings
    case sourceBookDetails(sourceId: String, item: PartialSourceBook)
    case sourcePagedViewMoreItems(sourceId: String, viewMoreId: String)
    case sourceSearchPagedResults(searchRequest: SearchRequest, sourceId: String)
    case sourceExtensionDetails(sourceId: String)

    var id: String {
        switch self {
        case .localDetails:
            "localDetails"
        case .sourceSearch:
            "sourceSearch"
        case .source(sourceUrl: _):
            "source"
        case .sourceSettings:
            "sourceSettings"
        case .sourceBookDetails(sourceId: _, item: _):
            "sourceBookDetails"
        case .sourcePagedViewMoreItems(sourceId: _, viewMoreId: _):
            "sourcePagedViewMoreItems"
        case .sourceSearchPagedResults(searchRequest: _, sourceId: _):
            "sourceSearchPagedResults"
        case .downloadManager:
            "downloadManager"
        case .sourceExtensionDetails(sourceId: _):
            "sourceDetails"
        }
    }
}

public enum SideMenuNavigation: String, Hashable, CaseIterable {
    case library = "Library"
    case discover = "Discover"
    case search = "Search"
    case settings = "Settings"
    case readingNow = "Reading Now"

    var icon: String {
        switch self {
        case .library:
            "books.vertical.fill"
        case .discover:
            "shippingbox"
        case .search:
            "magnifyingglass"
        case .settings:
            "gear"
        case .readingNow:
            "book.fill"
        }
    }
}

@Observable
public class Navigator {
    public var path: [NavigatorDestination] = []
    public var sideMenuTab: SideMenuNavigation = .library

    public init() {}

    public func navigate(to: NavigatorDestination) {
        path.append(to)
    }
}

extension View {
    func withNavigator() -> some View {
        navigationDestination(for: NavigatorDestination.self) { destination in
            switch destination {
            case .localDetails(book: let book):
                BookDetailView(book: book)
            case .sourceSearch(search: let search):
                SourceSearch(searchText: search)
            case .source(sourceUrl: let sourceUrl):
                SourceView(sourceUrl: sourceUrl)
            case .sourceSettings:
                SettingsSourcesView()
            case .sourceBookDetails(sourceId: let sourceId, item: let item):
                SourceBookDetailsView(sourceId: sourceId, item: item)
            case .sourcePagedViewMoreItems(sourceId: let sourceId, viewMoreId: let viewMoreId):
                PagedViewMoreItems(sourceId: sourceId, viewMoreId: viewMoreId)
            case .sourceSearchPagedResults(searchRequest: let searchRequest, sourceId: let sourceId):
                SourcesSearchPagedResultsView(searchRequest: searchRequest, sourceId: sourceId)
            case .downloadManager:
                DownloadManagerView()
            case .sourceExtensionDetails(sourceId: let sourceId):
                SourceExtensionDetails(sourceId: sourceId)
            }
        }
    }
}
