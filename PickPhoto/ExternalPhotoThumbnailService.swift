//
//  ExternalPhotoThumbnailService.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import UIKit

@MainActor
final class ExternalPhotoThumbnailService {
    static let shared = ExternalPhotoThumbnailService()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 600
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    func thumbnail(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let key = url as NSURL

        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        guard let image = await Self.generateThumbnail(for: url, maxPixelSize: maxPixelSize) else {
            return nil
        }

        cache.setObject(image, forKey: key, cost: image.cacheCost)
        return image
    }

    private nonisolated static func generateThumbnail(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let context = "thumbnail \(url.lastPathComponent)"

            do {
                let data = try ExternalPhotoFileReader.readImageData(from: url, context: context)
                return ExternalPhotoFileReader.decodeFullResolutionImage(
                    from: data,
                    url: url,
                    context: context
                )
            } catch {
                print("[ExternalPhotoThumbnailService] \(context) failed: \(error.localizedDescription)")
                return nil
            }
        }.value
    }
}

private extension UIImage {
    var cacheCost: Int {
        guard let cgImage else {
            return 1
        }

        return cgImage.bytesPerRow * cgImage.height
    }
}
