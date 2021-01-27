//
//  FileCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
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
		detailTextLabel?.text = "\(item.size) KB"
		if #available(iOS 13.0, *) {
			detailTextLabel?.textColor = .secondaryLabel
		} else {
			detailTextLabel?.textColor = UIColor(named: "secondaryLabel")
		}
		imageView?.image = UIImage(named: "file-type-unknown")
		imageView?.highlightedImage = UIImage(named: "file-type-unknown-selected")
	}

	@available(iOS 14, *)
	override func updateConfiguration(using state: UICellConfigurationState) {
		guard let item = item else {
			return
		}
		var content = defaultContentConfiguration().updated(for: state)
		if state.isHighlighted || state.isSelected {
			content.image = UIImage(named: "file-type-unknown-selected")
		} else {
			content.image = UIImage(named: "file-type-unknown")
		}
		content.text = item.name
		content.secondaryText = "\(item.size) KB"
		content.secondaryTextProperties.color = .secondaryLabel
		contentConfiguration = content
	}
}
