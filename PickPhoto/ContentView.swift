//
//  ContentView.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ExternalPhotoBrowserViewModel()
    @State private var isShowingDirectoryPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.photos.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .navigationTitle("External Photos")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if !viewModel.photos.isEmpty {
                        Button {
                            viewModel.selectAllPhotos()
                        } label: {
                            Label("Select All", systemImage: "checkmark.circle")
                        }
                        .disabled(viewModel.selectedPhotoIDs.count == viewModel.photos.count)

                        Button {
                            viewModel.clearSelection()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                        .disabled(viewModel.selectedPhotoIDs.isEmpty)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingDirectoryPicker = true
                    } label: {
                        Label("Choose Source", systemImage: "folder.badge.plus")
                    }
                    .disabled(viewModel.importState.isImporting)
                }

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        viewModel.importSelectedPhotos()
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!viewModel.canImportSelectedPhotos)
                }
            }
            .safeAreaInset(edge: .bottom) {
                statusBar
            }
            .sheet(isPresented: $isShowingDirectoryPicker) {
                DirectoryPicker { url in
                    viewModel.openDirectory(url)
                }
            }
            .alert("Unable to Browse Folder", isPresented: $viewModel.isShowingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Photos Loaded", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Choose a folder from the connected USB or SD card.")
        } actions: {
            Button {
                isShowingDirectoryPicker = true
            } label: {
                Label("Choose Source", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var photoGrid: some View {
        ExternalPhotoCollectionView(
            photos: viewModel.photos,
            selectedPhotoIDs: viewModel.selectedPhotoIDs,
            importedPhotoIDs: viewModel.importedPhotoIDs
        ) { photo in
            viewModel.toggleSelection(for: photo)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let sourceName = viewModel.sourceName {
                Text(sourceName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }

            HStack {
                Text(viewModel.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if case let .importing(completed, total) = viewModel.importState {
                ProgressView(value: Double(completed), total: Double(total))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
