//
//  ExternalPhotoScanner.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import Foundation
import UniformTypeIdentifiers

enum ExternalPhotoScanner {
    nonisolated static func scan(directoryURL: URL) throws -> [ExternalPhoto] {
        print("[ExternalPhotoScanner] scan directory url=\(directoryURL.absoluteString)")
        print("[ExternalPhotoScanner] scan directory path=\(directoryURL.path)")

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentTypeKey,
            .fileSizeKey,
            .creationDateKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw ExternalPhotoBrowserError.unableToReadDirectory
        }

        var photos: [ExternalPhoto] = []

        for case let fileURL as URL in enumerator {
            if Task.isCancelled {
                break
            }

            let values = try fileURL.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else {
                continue
            }

            guard isSupportedImage(url: fileURL, contentType: values.contentType) else {
                continue
            }

            print("[ExternalPhotoScanner] image file=\(fileURL.absoluteString) size=\(values.fileSize ?? 0) type=\(values.contentType?.identifier ?? "nil")")

            photos.append(
                ExternalPhoto(
                    url: fileURL,
                    fileSize: Int64(values.fileSize ?? 0),
                    creationDate: values.creationDate,
                    contentTypeIdentifier: values.contentType?.identifier
                )
            )
        }

        print("[ExternalPhotoScanner] found photos=\(photos.count)")

        return photos.sorted {
            switch ($0.creationDate, $1.creationDate) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate > rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
            }
        }
    }

    nonisolated private static func isSupportedImage(url: URL, contentType: UTType?) -> Bool {
        if contentType?.conforms(to: .image) == true {
            return true
        }

        let imageExtensions: Set<String> = [
            "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff",
            "gif", "bmp", "dng", "cr2", "cr3", "nef", "arw", "raf", "rw2"
        ]

        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}
