//
//  ExternalPhotoCollectionView.swift
//  PickPhoto
//
//  Created by lucasjiang on 2026/5/11.
//

import SwiftUI
import UIKit

struct ExternalPhotoCollectionView: UIViewRepresentable {
    let photos: [ExternalPhoto]
    let selectedPhotoIDs: Set<ExternalPhoto.ID>
    let importedPhotoIDs: Set<ExternalPhoto.ID>
    let onToggleSelection: (ExternalPhoto) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Constants.spacing
        layout.minimumLineSpacing = Constants.spacing
        layout.sectionInset = Constants.contentInsets

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(
            ExternalPhotoCollectionViewCell.self,
            forCellWithReuseIdentifier: ExternalPhotoCollectionViewCell.reuseIdentifier
        )
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        let previousPhotoIDs = context.coordinator.photos.map(\.id)
        let selectionChanged = context.coordinator.selectedPhotoIDs != selectedPhotoIDs
        let importedChanged = context.coordinator.importedPhotoIDs != importedPhotoIDs

        context.coordinator.update(self)
        collectionView.collectionViewLayout.invalidateLayout()

        if previousPhotoIDs != photos.map(\.id) {
            collectionView.reloadData()
        } else if selectionChanged || importedChanged {
            context.coordinator.reconfigureVisibleCells(in: collectionView)
        }
    }
}

private enum Constants {
    static let minCellWidth: CGFloat = 104
    static let maxCellWidth: CGFloat = 160
    static let spacing: CGFloat = 12
    static let contentInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}

extension ExternalPhotoCollectionView {
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        private var parent: ExternalPhotoCollectionView

        var photos: [ExternalPhoto] {
            parent.photos
        }

        var selectedPhotoIDs: Set<ExternalPhoto.ID> {
            parent.selectedPhotoIDs
        }

        var importedPhotoIDs: Set<ExternalPhoto.ID> {
            parent.importedPhotoIDs
        }

        init(_ parent: ExternalPhotoCollectionView) {
            self.parent = parent
        }

        func update(_ parent: ExternalPhotoCollectionView) {
            self.parent = parent
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.photos.count
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ExternalPhotoCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as? ExternalPhotoCollectionViewCell else {
                return UICollectionViewCell()
            }

            configure(cell, at: indexPath, in: collectionView)
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard parent.photos.indices.contains(indexPath.item) else {
                return
            }

            parent.onToggleSelection(parent.photos[indexPath.item])
        }

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            let width = cellWidth(in: collectionView)
            return CGSize(width: width, height: width)
        }

        func reconfigureVisibleCells(in collectionView: UICollectionView) {
            for indexPath in collectionView.indexPathsForVisibleItems {
                guard let cell = collectionView.cellForItem(at: indexPath) as? ExternalPhotoCollectionViewCell else {
                    continue
                }

                configure(cell, at: indexPath, in: collectionView)
            }
        }

        private func configure(
            _ cell: ExternalPhotoCollectionViewCell,
            at indexPath: IndexPath,
            in collectionView: UICollectionView
        ) {
            guard parent.photos.indices.contains(indexPath.item) else {
                return
            }

            let photo = parent.photos[indexPath.item]
            let pixelSize = cellWidth(in: collectionView) * (collectionView.window?.screen.scale ?? UIScreen.main.scale)
            cell.configure(
                photo: photo,
                isSelected: parent.selectedPhotoIDs.contains(photo.id),
                isImported: parent.importedPhotoIDs.contains(photo.id),
                maxPixelSize: ceil(pixelSize)
            )
        }

        private func cellWidth(in collectionView: UICollectionView) -> CGFloat {
            let horizontalInsets = Constants.contentInsets.left +
                Constants.contentInsets.right +
                collectionView.adjustedContentInset.left +
                collectionView.adjustedContentInset.right
            let availableWidth = max(1, collectionView.bounds.width - horizontalInsets)
            let columns = max(
                1,
                Int((availableWidth + Constants.spacing) / (Constants.minCellWidth + Constants.spacing))
            )
            let totalSpacing = CGFloat(columns - 1) * Constants.spacing
            let uncappedWidth = floor((availableWidth - totalSpacing) / CGFloat(columns))
            return min(Constants.maxCellWidth, max(Constants.minCellWidth, uncappedWidth))
        }
    }
}

private final class ExternalPhotoCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "ExternalPhotoCollectionViewCell"

    private let imageView = UIImageView()
    private let placeholderView = UIActivityIndicatorView(style: .medium)
    private let selectionImageView = UIImageView()
    private let importedImageView = UIImageView()
    private let titleBackgroundView = UIView()
    private let titleLabel = UILabel()

    private var representedPhotoID: ExternalPhoto.ID?
    private var thumbnailTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        representedPhotoID = nil
        thumbnailTask?.cancel()
        thumbnailTask = nil
        imageView.image = nil
        titleLabel.text = nil
        placeholderView.stopAnimating()
        updateSelectionState(isSelected: false)
        updateImportedState(isImported: false)
    }

    func configure(photo: ExternalPhoto, isSelected: Bool, isImported: Bool, maxPixelSize: CGFloat) {
        titleLabel.text = photo.fileName
        updateSelectionState(isSelected: isSelected)
        updateImportedState(isImported: isImported)

        guard representedPhotoID != photo.id else {
            return
        }

        representedPhotoID = photo.id
        thumbnailTask?.cancel()
        imageView.image = nil
        placeholderView.startAnimating()

        let photoID = photo.id
        let photoURL = photo.url
        thumbnailTask = Task { @MainActor [weak self] in
            let image = await ExternalPhotoThumbnailService.shared.thumbnail(
                for: photoURL,
                maxPixelSize: maxPixelSize
            )

            guard !Task.isCancelled, let self, self.representedPhotoID == photoID else {
                return
            }

            self.imageView.image = image
            self.placeholderView.stopAnimating()
            self.thumbnailTask = nil
        }
    }

    private func setupViews() {
        backgroundColor = .clear
        layer.cornerRadius = 8
        layer.borderWidth = 3
        layer.borderColor = UIColor.clear.cgColor

        contentView.backgroundColor = .secondarySystemFill
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        placeholderView.hidesWhenStopped = true
        placeholderView.translatesAutoresizingMaskIntoConstraints = false

        selectionImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold)
        selectionImageView.translatesAutoresizingMaskIntoConstraints = false

        importedImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold)
        importedImageView.tintColor = .systemGreen
        importedImageView.translatesAutoresizingMaskIntoConstraints = false

        titleBackgroundView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.72)
        titleBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .caption2)
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(imageView)
        contentView.addSubview(placeholderView)
        contentView.addSubview(titleBackgroundView)
        contentView.addSubview(selectionImageView)
        contentView.addSubview(importedImageView)
        titleBackgroundView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            placeholderView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            placeholderView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            selectionImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            selectionImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            selectionImageView.widthAnchor.constraint(equalToConstant: 24),
            selectionImageView.heightAnchor.constraint(equalToConstant: 24),

            importedImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            importedImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            importedImageView.widthAnchor.constraint(equalToConstant: 24),
            importedImageView.heightAnchor.constraint(equalToConstant: 24),

            titleBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titleBackgroundView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: titleBackgroundView.leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: titleBackgroundView.trailingAnchor, constant: -6),
            titleLabel.centerYAnchor.constraint(equalTo: titleBackgroundView.centerYAnchor)
        ])

        updateSelectionState(isSelected: false)
        updateImportedState(isImported: false)
    }

    private func updateSelectionState(isSelected: Bool) {
        layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
        selectionImageView.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        selectionImageView.tintColor = isSelected ? .systemBlue : .secondaryLabel
    }

    private func updateImportedState(isImported: Bool) {
        importedImageView.image = UIImage(systemName: "checkmark.circle.fill")
        importedImageView.isHidden = !isImported
    }
}
