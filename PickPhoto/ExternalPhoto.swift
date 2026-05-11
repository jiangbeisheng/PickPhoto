//
//  ExternalPhoto.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import Foundation

struct ExternalPhoto: Identifiable, Hashable {
    let id: URL
    let url: URL
    let fileName: String
    let fileSize: Int64
    let creationDate: Date?
    let contentTypeIdentifier: String?

    nonisolated init(
        url: URL,
        fileSize: Int64,
        creationDate: Date?,
        contentTypeIdentifier: String?
    ) {
        self.id = url
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileSize = fileSize
        self.creationDate = creationDate
        self.contentTypeIdentifier = contentTypeIdentifier
    }
}
