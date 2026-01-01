//
//  GIFSearchView.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.9: GIF search and display with Giphy integration
//

import SwiftUI

struct GIFSearchView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @State private var searchText = ""
    @State private var gifs: [GiphyService.GiphyGif] = []
    @State private var isLoading = false
    @State private var showSearchKeyboard = false

    private let giphyService = GiphyService()
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 2)

    var body: some View {
        VStack(spacing: 0) {
            // Search bar - tap to show inline keyboard
            Button(action: {
                showSearchKeyboard = true
                KeyboardHaptics.lightTap()
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Search GIFs" : searchText)
                        .foregroundColor(searchText.isEmpty ? .secondary : .primary)
                    Spacer()
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            gifs = []
                            loadTrending()
                            KeyboardHaptics.lightTap()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    // Giphy attribution (required by their API terms)
                    Text("GIPHY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 8)

            if showSearchKeyboard {
                // Inline search keyboard
                InlineSearchKeyboard(
                    text: $searchText,
                    onDismiss: { showSearchKeyboard = false },
                    onSearch: { searchGIFs() }
                )
            } else if isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if gifs.isEmpty && !searchText.isEmpty {
                // No results
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No GIFs found")
                        .font(.headline)
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                // GIF grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(gifs) { gif in
                            GIFCell(gif: gif) {
                                insertGIF(gif)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadTrending()
        }
    }

    private func searchGIFs() {
        guard !searchText.isEmpty else { return }
        isLoading = true
        Task {
            do {
                gifs = try await giphyService.search(searchText)
            } catch {
                gifs = []
            }
            isLoading = false
        }
    }

    private func loadTrending() {
        isLoading = true
        Task {
            do {
                gifs = try await giphyService.trending()
            } catch {
                gifs = []
            }
            isLoading = false
        }
    }

    private func insertGIF(_ gif: GiphyService.GiphyGif) {
        // Insert GIF URL - most apps will render it
        viewModel.textDocumentProxy?.insertText(gif.images.original.url)
        KeyboardHaptics.mediumTap()
    }
}

struct GIFCell: View {
    let gif: GiphyService.GiphyGif
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AsyncImage(url: URL(string: gif.images.fixedWidthSmall.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    GIFSearchView(viewModel: KeyboardViewModel())
        .preferredColorScheme(.dark)
}
