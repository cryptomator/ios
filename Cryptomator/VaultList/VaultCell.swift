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
	lazy var lockButton: ActionButton = {
		let button = ActionButton()
		let lockSymbol = UIImage(systemName: "lock.open.fill",
		                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .regular, scale: .default))
		button.setImage(lockSymbol, for: .normal)
		button.sizeToFit()
		button.isHidden = true
		return button
	}()

	var isUnlocked: Bool = false {
		didSet {
			guard isUnlocked != oldValue else {
				return
			}
			print(isUnlocked)
			lockButton.isHidden = !isUnlocked
		}
	}

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setCustomAccessoryView()
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

	private func setCustomAccessoryView() {
		let detailDisclosureIndicator = UIImageView(image: UIImage(systemName: "chevron.forward",
		                                                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold, scale: .default)))
		detailDisclosureIndicator.tintColor = .tertiaryLabel
		detailDisclosureIndicator.contentMode = .right
		let containerView = UIStackView(arrangedSubviews: [lockButton, detailDisclosureIndicator])
		let spacing: CGFloat = 10
		containerView.spacing = spacing
		let width = lockButton.bounds.width + detailDisclosureIndicator.bounds.width + spacing
		containerView.frame = CGRect(x: 0, y: 0, width: width, height: frame.height)
		accessoryView = containerView
	}
}
