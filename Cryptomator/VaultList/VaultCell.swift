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
	var vault: VaultInfo?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		accessoryType = .disclosureIndicator
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with vault: VaultInfo) {
		imageView?.image = UIImage(vaultIconFor: vault.cloudProviderType, state: .normal)
		imageView?.highlightedImage = UIImage(vaultIconFor: vault.cloudProviderType, state: .highlighted)
		textLabel?.text = vault.vaultName
		detailTextLabel?.text = vault.vaultPath.path
		detailTextLabel?.textColor = UIColor(named: "secondaryLabel")
	}

	@available(iOS 14, *)
	override func updateConfiguration(using state: UICellConfigurationState) {
		guard let vault = vault else {
			return
		}
		var content = defaultContentConfiguration().updated(for: state)
		if state.isHighlighted || state.isSelected {
			content.image = UIImage(vaultIconFor: vault.cloudProviderType, state: .highlighted)
		} else {
			content.image = UIImage(vaultIconFor: vault.cloudProviderType, state: .normal)
		}
		content.text = vault.vaultName
		content.secondaryText = vault.vaultPath.path
		content.secondaryTextProperties.color = .secondaryLabel
		contentConfiguration = content
	}
}
