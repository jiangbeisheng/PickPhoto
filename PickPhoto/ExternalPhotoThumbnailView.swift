//
//  ExternalPhotoThumbnailView.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/10.
//

import SwiftUI
import UIKit

struct ExternalPhotoThumbnailView: View {
    let photo: ExternalPhoto
    let isSelected: Bool
    let isImported: Bool
    let thumbnailService: ExternalPhotoThumbnailService

    @State private var thumbnail: UIImage?

    init(
        photo: ExternalPhoto,
        isSelected: Bool,
        isImported: Bool,
        thumbnailService: ExternalPhotoThumbnailService
    ) {
        self.photo = photo
        self.isSelected = isSelected
        self.isImported = isImported
        self.thumbnailService = thumbnailService
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .clipped()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(isSelected ? .white : .secondary, isSelected ? .blue : .clear)
                .padding(6)
        }
        .overlay(alignment: .topLeading) {
            if isImported {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .padding(6)
                    .accessibilityLabel("Already imported")
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(photo.fileName)
                .font(.caption2)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(.rect(bottomLeadingRadius: 8, bottomTrailingRadius: 8))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? .blue : .clear, lineWidth: 3)
        }
        .task(id: photo.id) {
            thumbnail = nil
            thumbnail = await thumbnailService.thumbnail(for: photo.url, maxPixelSize: 320)
        }
    }
}
