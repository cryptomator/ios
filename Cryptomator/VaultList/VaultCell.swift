//
//  VaultCell.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 12.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class VaultCell: UITableViewCell {
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		accessoryType = .disclosureIndicator
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with vault: VaultInfo) {
		let image = UIImage(for: vault.cloudProviderType)
		if #available(iOS 14, *) {
			var content = defaultContentConfiguration()
			content.text = vault.vaultPath.lastPathComponent
			content.secondaryText = vault.vaultPath.path
			content.secondaryTextProperties.color = .secondaryLabel
			content.image = image
			contentConfiguration = content
		} else {
			textLabel?.text = vault.vaultPath.lastPathComponent
			detailTextLabel?.text = vault.vaultPath.path
			detailTextLabel?.textColor = UIColor(named: "secondaryLabel")
			imageView?.image = image
		}
	}
}
