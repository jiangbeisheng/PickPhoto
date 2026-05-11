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
    nonisolated static func readImageData(from url: URL, context: String) throws -> Data {
        let originalFileSize = logURL(url, context: context)

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        print("[ExternalPhotoFileReader] \(context) startAccessingSecurityScopedResource=\(didStartAccessing)")
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
                print("[ExternalPhotoFileReader] \(context) stopAccessingSecurityScopedResource")
            }
        }

        do {
            let data = try coordinatedRead(from: url, context: context)
            print("[ExternalPhotoFileReader] \(context) original Data bytes=\(data.count)")

            guard !data.isEmpty else {
                print("[ExternalPhotoFileReader] \(context) failed: empty Data")
                throw ExternalPhotoFileReadError.emptyData(url)
            }

            if let originalFileSize {
                print("[ExternalPhotoFileReader] \(context) resource fileSize=\(originalFileSize) Data bytes=\(data.count)")

                if originalFileSize > 0 && originalFileSize != data.count {
                    print("[ExternalPhotoFileReader] \(context) warning: resource fileSize and Data bytes differ")
                }
            }

            return data
        } catch {
            print("[ExternalPhotoFileReader] \(context) read failed: \(error.localizedDescription)")
            throw error
        }
    }

    nonisolated static func decodeFullResolutionImage(from data: Data, url: URL, context: String) -> UIImage? {
        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            print("[ExternalPhotoFileReader] \(context) CGImageSourceCreateWithData=nil url=\(url.absoluteString)")
            let fallbackImage = UIImage(data: data)
            logUIImage(fallbackImage, context: "\(context) UIImage(data:) fallback")
            return fallbackImage
        }

        let typeIdentifier = CGImageSourceGetType(source) as String?
        let imageCount = CGImageSourceGetCount(source)
        print("[ExternalPhotoFileReader] \(context) imageSource type=\(typeIdentifier ?? "nil") count=\(imageCount)")

        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            let width = properties[kCGImagePropertyPixelWidth] ?? "nil"
            let height = properties[kCGImagePropertyPixelHeight] ?? "nil"
            let orientation = properties[kCGImagePropertyOrientation] ?? "nil"
            print("[ExternalPhotoFileReader] \(context) source pixels=\(width)x\(height) orientation=\(orientation)")
        } else {
            print("[ExternalPhotoFileReader] \(context) source properties=nil")
        }

        let imageOptions = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary

        if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, imageOptions) {
            print("[ExternalPhotoFileReader] \(context) full CGImage width=\(cgImage.width) height=\(cgImage.height)")
            let image = UIImage(cgImage: cgImage)
            logUIImage(image, context: "\(context) full image")
            return image
        }

        print("[ExternalPhotoFileReader] \(context) CGImageSourceCreateImageAtIndex=nil, trying UIImage(data:)")
        let fallbackImage = UIImage(data: data)
        logUIImage(fallbackImage, context: "\(context) UIImage(data:) fallback")
        return fallbackImage
    }

    nonisolated static func logUIImage(_ image: UIImage?, context: String) {
        guard let image else {
            print("[ExternalPhotoFileReader] \(context) UIImage=nil")
            return
        }

        let cgWidth = image.cgImage?.width.description ?? "nil"
        let cgHeight = image.cgImage?.height.description ?? "nil"
        print("[ExternalPhotoFileReader] \(context) UIImage ok size=\(image.size) scale=\(image.scale) cgImage=\(cgWidth)x\(cgHeight)")
    }

    nonisolated private static func coordinatedRead(from url: URL, context: String) throws -> Data {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                if coordinatedURL != url {
                    print("[ExternalPhotoFileReader] \(context) coordinatedURL=\(coordinatedURL.absoluteString)")
                }
                readResult = .success(try Data(contentsOf: coordinatedURL, options: []))
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

        return try Data(contentsOf: url, options: [])
    }

    nonisolated static func makeTemporaryOriginalFile(from data: Data, originalURL: URL, context: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PickPhotoOriginalImports", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileName = UUID().uuidString + "-" + originalURL.lastPathComponent
        let temporaryURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: temporaryURL, options: .atomic)

        let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
        print("[ExternalPhotoFileReader] \(context) import fileURL=\(temporaryURL.path)")
        print("[ExternalPhotoFileReader] \(context) import file size=\(values.fileSize ?? data.count)")
        return temporaryURL
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

enum ExternalPhotoFileReadError: LocalizedError {
    case emptyData(URL)

    var errorDescription: String? {
        switch self {
        case let .emptyData(url):
            "The image data is empty: \(url.lastPathComponent)"
        }
    }
}
