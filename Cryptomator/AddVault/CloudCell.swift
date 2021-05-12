//
//  CloudCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

class CloudCell: UITableViewCell {
	var cloudProviderType: CloudProviderType?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		accessoryType = .disclosureIndicator
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with cloudProviderType: CloudProviderType) {
		imageView?.image = UIImage(storageIconFor: cloudProviderType)
		textLabel?.text = cloudProviderType.localizedString()
	}

	@available(iOS 14, *)
	override func updateConfiguration(using state: UICellConfigurationState) {
		guard let cloudProviderType = cloudProviderType else {
			return
		}
		var content = defaultContentConfiguration().updated(for: state)
		content.image = UIImage(storageIconFor: cloudProviderType)
		content.text = cloudProviderType.localizedString()
		contentConfiguration = content
	}
}
