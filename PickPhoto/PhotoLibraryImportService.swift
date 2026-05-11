//
//  PhotoLibraryImportService.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import Foundation
import Photos

struct PhotoLibraryImportService {
    func requestAddOnlyAccess() async throws {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch currentStatus {
        case .authorized, .limited:
            return
        case .notDetermined:
            let requestedStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard requestedStatus == .authorized || requestedStatus == .limited else {
                throw PhotoLibraryImportError.photoLibraryAccessDenied
            }
        default:
            throw PhotoLibraryImportError.photoLibraryAccessDenied
        }
    }

    func importPhoto(_ photo: ExternalPhoto) async throws {
        let context = "import \(photo.fileName)"
        let preparedImport = try await Task.detached(priority: .userInitiated) {
            print("[PhotoLibraryImportService] \(context) original file path=\(photo.url.path)")
            return try ExternalPhotoFileReader.makeTemporaryOriginalFile(
                from: photo.url,
                context: context
            )
        }.value

        print("[PhotoLibraryImportService] \(context) addResource fileURL=\(preparedImport.fileURL.path)")
        print("[PhotoLibraryImportService] \(context) addResource original bytes=\(preparedImport.byteCount)")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = photo.fileName
                options.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: preparedImport.fileURL, options: options)
            } completionHandler: { success, error in
                try? FileManager.default.removeItem(at: preparedImport.fileURL)

                if let error {
                    print("[PhotoLibraryImportService] \(context) failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if success {
                    print("[PhotoLibraryImportService] \(context) imported file bytes=\(preparedImport.byteCount)")
                    print("[PhotoLibraryImportService] \(context) succeeded")
                    continuation.resume()
                } else {
                    print("[PhotoLibraryImportService] \(context) failed: unknown import failure")
                    continuation.resume(throwing: PhotoLibraryImportError.unknownImportFailure)
                }
            }
        }
    }
}

enum PhotoLibraryImportError: LocalizedError {
    case photoLibraryAccessDenied
    case unknownImportFailure

    var errorDescription: String? {
        switch self {
        case .photoLibraryAccessDenied:
            "Photo library add access was denied. Enable photo library access in Settings to import photos."
        case .unknownImportFailure:
            "The photo could not be imported."
        }
    }
}
