//
//  SecurityScopedResource.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import Foundation

final class SecurityScopedResource {
    let url: URL
    private let didStartAccessing: Bool

    init(url: URL) throws {
        self.url = url
        self.didStartAccessing = url.startAccessingSecurityScopedResource()
        print("[SecurityScopedResource] url=\(url.absoluteString)")
        print("[SecurityScopedResource] startAccessingSecurityScopedResource=\(didStartAccessing) isFileURL=\(url.isFileURL)")

        guard didStartAccessing || url.isFileURL else {
            throw ExternalPhotoBrowserError.unableToAccessSecurityScopedResource
        }
    }

    deinit {
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
            print("[SecurityScopedResource] stopAccessingSecurityScopedResource url=\(url.absoluteString)")
        }
    }
}
