//
//  FileCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import UIKit

class FileCell: UITableViewCell, CloudItemCell {
	var item: CloudItemMetadata?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
		isUserInteractionEnabled = false
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with item: CloudItemMetadata) {
		textLabel?.text = item.name
		detailTextLabel?.text = FileCell.formattedTextForSize(from: item)
		detailTextLabel?.textColor = .secondaryLabel
		imageView?.image = UIImage(systemName: "doc") // UIImage(named: "file-type-unknown")
		imageView?.highlightedImage = UIImage(systemName: "doc.fill")
	}

	@available(iOS 14, *)
	override func updateConfiguration(using state: UICellConfigurationState) {
		guard let item = item else {
			return
		}
		var content = defaultContentConfiguration().updated(for: state)
		if state.isHighlighted || state.isSelected {
			content.image = UIImage(systemName: "doc.fill")
		} else {
			content.image = UIImage(systemName: "doc")
		}
		content.text = item.name
		content.secondaryText = FileCell.formattedTextForSize(from: item)
		content.secondaryTextProperties.color = .secondaryLabel
		contentConfiguration = content
	}

	private static func formattedTextForSize(from item: CloudItemMetadata) -> String? {
		guard let size = item.size else {
			return nil
		}
		return ByteCountFormatter().string(fromByteCount: Int64(size))
	}
}
