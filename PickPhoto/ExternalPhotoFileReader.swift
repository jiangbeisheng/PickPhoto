//
//  ExternalPhotoFileReader.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum ExternalPhotoFileReader {
    nonisolated static func decodeThumbnail(from url: URL, maxPixelSize: CGFloat, context: String) throws -> UIImage? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try autoreleasepool {
            try coordinatedRead(from: url, context: context) { readableURL in
                let sourceOptions = [
                    kCGImageSourceShouldCache: false
                ] as CFDictionary

                guard let source = CGImageSourceCreateWithURL(readableURL as CFURL, sourceOptions) else {
                    print("[ExternalPhotoFileReader] \(context) CGImageSourceCreateWithURL=nil url=\(readableURL.absoluteString)")
                    return nil
                }

                let thumbnailOptions = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up)))
                ] as CFDictionary

                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
                    print("[ExternalPhotoFileReader] \(context) CGImageSourceCreateThumbnailAtIndex=nil")
                    return nil
                }

                return UIImage(cgImage: cgImage)
            }
        }
    }

    nonisolated static func makeTemporaryOriginalFile(from originalURL: URL, context: String) throws -> ExternalPhotoTemporaryFile {
        let originalFileSize = logURL(originalURL, context: context)

        let didStartAccessing = originalURL.startAccessingSecurityScopedResource()
        print("[ExternalPhotoFileReader] \(context) startAccessingSecurityScopedResource=\(didStartAccessing)")
        defer {
            if didStartAccessing {
                originalURL.stopAccessingSecurityScopedResource()
                print("[ExternalPhotoFileReader] \(context) stopAccessingSecurityScopedResource")
            }
        }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PickPhotoOriginalImports", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileName = UUID().uuidString + "-" + originalURL.lastPathComponent
        let temporaryURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)

        do {
            try autoreleasepool {
                try coordinatedRead(from: originalURL, context: context) { readableURL in
                    if FileManager.default.fileExists(atPath: temporaryURL.path) {
                        try FileManager.default.removeItem(at: temporaryURL)
                    }

                    try FileManager.default.copyItem(at: readableURL, to: temporaryURL)
                }
            }

            let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
            let byteCount = Int64(values.fileSize ?? originalFileSize ?? 0)
            print("[ExternalPhotoFileReader] \(context) import fileURL=\(temporaryURL.path)")
            print("[ExternalPhotoFileReader] \(context) import file size=\(byteCount)")

            guard byteCount > 0 else {
                throw ExternalPhotoFileReadError.emptyFile(originalURL)
            }

            return ExternalPhotoTemporaryFile(fileURL: temporaryURL, byteCount: byteCount)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    nonisolated private static func coordinatedRead<ResultValue>(
        from url: URL,
        context: String,
        _ body: (URL) throws -> ResultValue
    ) throws -> ResultValue {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var readResult: Result<ResultValue, Error>?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                if coordinatedURL != url {
                    print("[ExternalPhotoFileReader] \(context) coordinatedURL=\(coordinatedURL.absoluteString)")
                }
                readResult = .success(try body(coordinatedURL))
            } catch {
                readResult = .failure(error)
            }
        }

        if let readResult {
            return try readResult.get()
        }

        if let coordinationError {
            print("[ExternalPhotoFileReader] \(context) coordination failed: \(coordinationError.localizedDescription), trying direct read")
        }

        return try body(url)
    }

    nonisolated private static func logURL(_ url: URL, context: String) -> Int? {
        print("[ExternalPhotoFileReader] \(context) url=\(url.absoluteString)")
        print("[ExternalPhotoFileReader] \(context) path=\(url.path)")
        print("[ExternalPhotoFileReader] \(context) isFileURL=\(url.isFileURL) scheme=\(url.scheme ?? "nil") ext=\(url.pathExtension.lowercased())")

        do {
            let keys: Set<URLResourceKey> = [
                .contentTypeKey,
                .fileSizeKey,
                .isRegularFileKey,
                .isReadableKey,
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey
            ]
            let values = try url.resourceValues(forKeys: keys)
            let isPlaceholder = values.isUbiquitousItem == true &&
                values.ubiquitousItemDownloadingStatus != .current &&
                values.ubiquitousItemDownloadingStatus != .downloaded
            print("[ExternalPhotoFileReader] \(context) resource contentType=\(values.contentType?.identifier ?? "nil") fileSize=\(values.fileSize?.description ?? "nil") isRegular=\(values.isRegularFile?.description ?? "nil") isReadable=\(values.isReadable?.description ?? "nil") isUbiquitous=\(values.isUbiquitousItem?.description ?? "nil") downloadStatus=\(values.ubiquitousItemDownloadingStatus?.rawValue ?? "nil") isPlaceholder=\(isPlaceholder)")
            return values.fileSize
        } catch {
            print("[ExternalPhotoFileReader] \(context) resourceValues failed: \(error.localizedDescription)")
            return nil
        }
    }
}

struct ExternalPhotoTemporaryFile: Sendable {
    let fileURL: URL
    let byteCount: Int64
}

enum ExternalPhotoFileReadError: LocalizedError {
    case emptyFile(URL)

    var errorDescription: String? {
        switch self {
        case let .emptyFile(url):
            "The image file is empty: \(url.lastPathComponent)"
        }
    }
}
