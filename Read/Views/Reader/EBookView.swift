//
//  EBookView.swift
//  Read
//
//  Created by Mirna Olvera on 3/6/24.
//

import RealmSwift
import SwiftUI

struct EBookView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var ebookViewModel: EBookReaderViewModel

    var realm = try! Realm()

    var book: Book
    var url: URL

    @State var contextMenuPosition: CGPoint = .zero
    @State var editMode = false
    @State var showContentSheet = false
    @State var showSettingsSheet = false
    @State var showContextMenu = false
    @State var showOverlay = false
    @State var currentHighlight: TappedHighlight? = nil

    init(url: URL, book: Book) {
        self.book = book
        self.url = url
        if let cfi = book.readingPosition?.epubCfi {
            self._ebookViewModel = StateObject(wrappedValue: EBookReaderViewModel(file: url, delay: .milliseconds(500), startCfi: cfi))

        } else {
            self._ebookViewModel = StateObject(wrappedValue: EBookReaderViewModel(file: url, delay: .milliseconds(500)))
        }
    }

    var body: some View {
        ZStack {
            Color(hex: ebookViewModel.theme.bg.rawValue)
                .ignoresSafeArea()

            EBookReader(viewModel: ebookViewModel)
                .onTapGesture {
                    Task {
                        let hasSelection = try await ebookViewModel.hasSelection()

                        if hasSelection {
                            showContextMenu = false
                        }
                    }
                }

            ReaderOverlay(title: book.title, currentLabel: ebookViewModel.currentLabel, showOverlay: $showOverlay, settingsButtonPressed: {
                showSettingsSheet.toggle()
            }) {
                showContentSheet.toggle()
            }

            if showContextMenu && contextMenuPosition != .zero {
                ReaderContextMenu(showContextMenu: $showContextMenu, editMode: $editMode, position: contextMenuPosition, onEvent: handleContentMenuEvent)
            }
        }
        .overlay {
            switch ebookViewModel.state {
            case .loading:
                ZStack {
                    Color(hex: ebookViewModel.theme.bg.rawValue)
                        .ignoresSafeArea()

                    ProgressView()
                }
            case .done:
                EmptyView()
            case .failure:
                ZStack {
                    Color(hex: ebookViewModel.theme.bg.rawValue)
                        .ignoresSafeArea()

                    VStack {
                        Text("Something went wrong")

                        Button("Return") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showContentSheet, content: {
            ReaderContent(toc: ebookViewModel.toc ?? [], isSelected: { item in ebookViewModel.isBookTocItemSelected(item: item) }, tocItemPressed: { item in
                ebookViewModel.goTo(cfi: item.href)
                showContentSheet = false
            }, currentTocItemId: ebookViewModel.currentTocItem?.id)
        })
        .sheet(isPresented: $showSettingsSheet, content: {
            ReaderSettings(theme: $ebookViewModel.theme, isPDF: false) {
                ebookViewModel.setBookTheme()
            }

        })
        .onReceive(ebookViewModel.onTapped, perform: handleTap)
        .onReceive(ebookViewModel.onRelocated, perform: relocated)
        .onReceive(ebookViewModel.onSelectionChanged, perform: selectionChanged)
        .onReceive(ebookViewModel.onHighlighted, perform: newHighlight)
        .onReceive(ebookViewModel.onTappedHighlight, perform: handleTappedHighlight)
        .onChange(of: ebookViewModel.renderedBook) { oldValue, newValue in
            if oldValue == false, newValue == true {
                // inject highlights
                var annotations = [Annotation]()

                book.highlights.forEach { highlight in

                    guard let cfi = highlight.cfi, let index = highlight.chapter else {
                        return
                    }

                    let ann = Annotation(index: index, value: cfi, color: highlight.backgroundColor)
                    annotations.append(ann)
                }

                ebookViewModel.setBookAnnotations(annotations: annotations)
            }
        }
        .onChange(of: showContextMenu) { oldValue, newValue in
            if oldValue == true, newValue == false {
                editMode = false
            }
        }
    }

    private func handleContentMenuEvent(_ event: ContextMenuEvent) {
        switch event {
        case .highlight:
            ebookViewModel.highlightSelection()
        case .copy:
            ebookViewModel.copySelection()
        case .delete:
            if let value = currentHighlight?.value {
                ebookViewModel.removeHighlight(value)
                deleteHighlight(value: value)
            }
        }

        showContextMenu = false
        currentHighlight = nil
    }

    private func deleteHighlight(value: String) {
        guard let thawedBook = book.thaw(), let realm = thawedBook.realm else {
            return
        }

        if let index = book.highlights.firstIndex(where: { bookhighlight in
            bookhighlight.cfi == value
        }) {
            try? realm.write {
                thawedBook.highlights.remove(at: index)
            }
        }
    }

    private func handleTappedHighlight(_ highlight: TappedHighlight) {
        showContextMenu = false

        let yPad = highlight.dir == "down" ? 70.0 : 0.0
        let annotationViewPosition = CGPoint(
            x: highlight.x,
            y: highlight.y + yPad
        )

        editMode = true
        currentHighlight = highlight
        contextMenuPosition = annotationViewPosition
        showContextMenu = true
    }

    private func newHighlight(highlight: (String, String?, Int?, String?)) {
        let (text, cfi, index, label) = highlight

        guard let cfi, let label, let index else {
            print("Missing selection data")
            return
        }

        guard let thawedBook = book.thaw() else {
            print("Unable to thaw book")
            return
        }

        if let bookRealm = book.realm?.thaw() {
            try! bookRealm.write {
                let pHighlight = BookHighlight()
                pHighlight.highlightText = text
                pHighlight.cfi = cfi
                pHighlight.chapter = index
                pHighlight.chapterTitle = label
                pHighlight.addedAt = .now
                pHighlight.updatedAt = .now

                thawedBook.highlights.append(pHighlight)
            }
        }
    }

    private func selectionChanged(selectionSelected: Selection?) {
        showContextMenu = false
        editMode = false

        guard let selectedText = selectionSelected?.string, selectedText.count > 0 else {
            showContextMenu = false
            return
        }

        guard let bounds = selectionSelected?.bounds else {
            showContextMenu = false
            return
        }

        let annotationViewPosition = CGPoint(
            x: bounds.origin.x,
            y: bounds.origin.y
        )

        contextMenuPosition = annotationViewPosition
        showContextMenu = true
    }

    private func relocated(relocate: Relocate) {
        let thawedBook = book.thaw()
        try! realm.write {
            if thawedBook?.readingPosition == nil {
                thawedBook?.readingPosition = ReadingPosition()
                thawedBook?.readingPosition?.progress = relocate.fraction
                thawedBook?.readingPosition?.updatedAt = relocate.updatedAt ?? .now
                thawedBook?.readingPosition?.epubCfi = relocate.cfi
            } else {
                thawedBook?.readingPosition?.progress = relocate.fraction
                thawedBook?.readingPosition?.updatedAt = relocate.updatedAt ?? .now
                thawedBook?.readingPosition?.epubCfi = relocate.cfi
            }
        }
    }

    private func handleTap(point: CGPoint) {
        showContextMenu = false

        withAnimation {
            showOverlay.toggle()
        }
    }
}

#Preview {
    EBookView(url: URL(string: "L")!, book: .example1)
}
