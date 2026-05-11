//
//  ExternalPhotoBrowserViewModel.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import Combine
import Foundation

@MainActor
final class ExternalPhotoBrowserViewModel: ObservableObject {
    @Published private(set) var sourceURL: URL?
    @Published private(set) var photos: [ExternalPhoto] = []
    @Published private(set) var selectedPhotoIDs: Set<ExternalPhoto.ID> = []
    @Published private(set) var importedPhotoIDs: Set<ExternalPhoto.ID> = []
    @Published private(set) var isScanning = false
    @Published private(set) var importState: ImportState = .idle
    @Published var isShowingError = false

    private(set) var errorMessage = ""
    private var scanTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var activeResource: SecurityScopedResource?
    private let importedPhotoIndex = ImportedPhotoIndex()
    private let importService = PhotoLibraryImportService()

    var sourceName: String? {
        sourceURL?.lastPathComponent
    }

    var statusText: String {
        if case let .importing(completed, total) = importState {
            "Importing \(completed) of \(total)..."
        } else if case let .completed(succeeded, failed) = importState {
            failed == 0 ? "Imported \(succeeded) photos" : "Imported \(succeeded), failed \(failed)"
        } else if isScanning {
            "Scanning for photos..."
        } else if photos.isEmpty {
            "No source selected"
        } else if selectedPhotoIDs.isEmpty {
            "\(photos.count) photos found"
        } else {
            "\(selectedPhotoIDs.count) selected of \(photos.count)"
        }
    }

    var selectedPhotos: [ExternalPhoto] {
        photos.filter { selectedPhotoIDs.contains($0.id) }
    }

    var canImportSelectedPhotos: Bool {
        !selectedPhotoIDs.isEmpty && !isScanning && !importState.isImporting
    }

    func openDirectory(_ url: URL) {
        scanTask?.cancel()
        importTask?.cancel()
        activeResource = nil
        ExternalPhotoThumbnailService.shared.clearCache()

        do {
            activeResource = try SecurityScopedResource(url: url)
        } catch {
            showError(error)
            return
        }

        sourceURL = url
        photos = []
        selectedPhotoIDs = []
        importedPhotoIDs = []
        isScanning = true
        importState = .idle

        scanTask = Task { [weak self] in
            guard let self else { return }

            do {
                let scannedPhotos = try await Task.detached(priority: .userInitiated) {
                    try ExternalPhotoScanner.scan(directoryURL: url)
                }.value

                guard !Task.isCancelled else { return }
                self.photos = scannedPhotos
                self.importedPhotoIDs = self.importedPhotoIndex.importedPhotoIDs(in: scannedPhotos)
                self.isScanning = false
            } catch {
                guard !Task.isCancelled else { return }
                self.isScanning = false
                self.showError(error)
            }
        }
    }

    func toggleSelection(for photo: ExternalPhoto) {
        guard !importState.isImporting else { return }

        if selectedPhotoIDs.contains(photo.id) {
            selectedPhotoIDs.remove(photo.id)
        } else {
            selectedPhotoIDs.insert(photo.id)
        }
    }

    func selectAllPhotos() {
        guard !importState.isImporting else { return }
        selectedPhotoIDs = Set(photos.map(\.id))
    }

    func clearSelection() {
        guard !importState.isImporting else { return }
        selectedPhotoIDs = []
    }

    func importSelectedPhotos() {
        guard canImportSelectedPhotos else { return }

        let photosToImport = selectedPhotos
        importState = .importing(completed: 0, total: photosToImport.count)

        importTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.importService.requestAddOnlyAccess()

                var succeeded = 0
                var failed = 0

                for photo in photosToImport {
                    if Task.isCancelled {
                        return
                    }

                    do {
                        try await self.importService.importPhoto(photo)
                        self.importedPhotoIndex.insert(photo)
                        self.importedPhotoIDs.insert(photo.id)
                        succeeded += 1
                    } catch {
                        failed += 1
                    }

                    self.importState = .importing(completed: succeeded + failed, total: photosToImport.count)
                }

                self.importState = .completed(succeeded: succeeded, failed: failed)
                if failed == 0 {
                    self.selectedPhotoIDs = []
                }
            } catch {
                self.importState = .idle
                self.showError(error)
            }
        }
    }

    private func showError(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        isShowingError = true
    }
}

enum ImportState: Equatable {
    case idle
    case importing(completed: Int, total: Int)
    case completed(succeeded: Int, failed: Int)

    var isImporting: Bool {
        if case .importing = self {
            return true
        }

        return false
    }
}
