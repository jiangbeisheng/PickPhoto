//
//  ImportedPhotoIndex.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import Foundation

struct ImportedPhotoSignature: Codable, Hashable {
    let fileName: String
    let fileSize: Int64

    init(photo: ExternalPhoto) {
        self.fileName = photo.fileName.lowercased()
        self.fileSize = photo.fileSize
    }
}

struct ImportedPhotoIndex {
    private let storageKey = "imported-photo-signatures"
    private let defaults = UserDefaults.standard

    func contains(_ photo: ExternalPhoto) -> Bool {
        load().contains(ImportedPhotoSignature(photo: photo))
    }

    func importedPhotoIDs(in photos: [ExternalPhoto]) -> Set<ExternalPhoto.ID> {
        let signatures = load()
        return Set(
            photos
                .filter { signatures.contains(ImportedPhotoSignature(photo: $0)) }
                .map(\.id)
        )
    }

    func insert(_ photo: ExternalPhoto) {
        var signatures = load()
        signatures.insert(ImportedPhotoSignature(photo: photo))
        save(signatures)
    }

    private func load() -> Set<ImportedPhotoSignature> {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }

        return (try? JSONDecoder().decode(Set<ImportedPhotoSignature>.self, from: data)) ?? []
    }

    private func save(_ signatures: Set<ImportedPhotoSignature>) {
        guard let data = try? JSONEncoder().encode(signatures) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}
