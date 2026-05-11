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
    private let generationLimiter = AsyncSemaphore(value: 3)

    private init() {
        cache.countLimit = 600
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    func thumbnail(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let key = cacheKey(for: url, maxPixelSize: maxPixelSize)

        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        await generationLimiter.wait()
        defer {
            Task {
                await generationLimiter.signal()
            }
        }

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
                return try ExternalPhotoFileReader.decodeThumbnail(
                    from: url,
                    maxPixelSize: maxPixelSize,
                    context: context
                )
            } catch {
                print("[ExternalPhotoThumbnailService] \(context) failed: \(error.localizedDescription)")
                return nil
            }
        }.value
    }

    private func cacheKey(for url: URL, maxPixelSize: CGFloat) -> NSURL {
        let pixelSize = max(1, Int(maxPixelSize.rounded(.up)))
        return url.appendingPathExtension("thumb-\(pixelSize)").absoluteURL as NSURL
    }
}

private actor AsyncSemaphore {
    private let limit: Int
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.limit = max(1, value)
        self.permits = max(1, value)
    }

    func wait() async {
        if permits > 0 {
            permits -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if waiters.isEmpty {
            permits = min(permits + 1, limit)
            return
        }

        waiters.removeFirst().resume()
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
