//
//  AccountCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
class AccountCellButton: UIButton {
	weak var cell: AccountCell?

	init(cell: AccountCell) {
		super.init(frame: .zero)
		self.cell = cell
		setImage(UIImage(named: "actions"), for: .normal)
		setImage(UIImage(named: "actions-selected"), for: .selected)
		sizeToFit()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func setSelected(_ selected: Bool) {
		UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve) {
			self.isSelected = selected
		}
	}
}

class AccountCell: UITableViewCell {
	var account: AccountCellContent?
	lazy var accessoryButton: AccountCellButton = {
		return AccountCellButton(cell: self)
	}()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		accessoryView = accessoryButton
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with account: AccountCellContent) {
		textLabel?.text = account.mainLabelText
		detailTextLabel?.text = account.detailLabelText
		detailTextLabel?.textColor = .secondaryLabel
	}

	@available(iOS 14, *)
	override func updateConfiguration(using state: UICellConfigurationState) {
		guard let account = account else {
			return
		}
		var content = defaultContentConfiguration().updated(for: state)

		content.text = account.mainLabelText
		content.secondaryText = account.detailLabelText
		content.secondaryTextProperties.color = .secondaryLabel
		contentConfiguration = content
	}
}
