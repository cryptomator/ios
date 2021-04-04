//
//  FolderCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import UIKit

class FolderCell: UITableViewCell, CloudItemCell {
	var item: CloudItemMetadata?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		accessoryType = .disclosureIndicator
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with item: CloudItemMetadata) {
		textLabel?.text = item.name
		imageView?.image = UIImage(named: "folder")
		imageView?.highlightedImage = UIImage(named: "folder-selected")
	}

	@available(iOS 14, *)
	override func updateConfiguration(using state: UICellConfigurationState) {
		guard let item = item else {
			return
		}
		var content = defaultContentConfiguration().updated(for: state)
		if state.isHighlighted || state.isSelected {
			content.image = UIImage(named: "folder-selected")
		} else {
			content.image = UIImage(named: "folder")
		}
		content.text = item.name
		contentConfiguration = content
	}
}
