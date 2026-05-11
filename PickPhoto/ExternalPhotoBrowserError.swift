//
//  ExternalPhotoBrowserError.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import Foundation

enum ExternalPhotoBrowserError: LocalizedError {
    case unableToAccessSecurityScopedResource
    case unableToReadDirectory

    var errorDescription: String? {
        switch self {
        case .unableToAccessSecurityScopedResource:
            "The selected folder could not be accessed. Choose the folder again from Files."
        case .unableToReadDirectory:
            "The selected folder could not be read."
        }
    }
}
