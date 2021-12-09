//
//  AccountCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class AccountCellButton: ActionButton {
	weak var cell: AccountCell?

	init(cell: AccountCell) {
		super.init()
		self.cell = cell
		let imageConfiguration = UIImage.SymbolConfiguration(font: UIFont.preferredFont(forTextStyle: .title2))
		setImage(UIImage(systemName: "chevron.down.circle", withConfiguration: imageConfiguration), for: .normal)
		setImage(UIImage(systemName: "chevron.down.circle.fill", withConfiguration: imageConfiguration), for: .selected)
		tintColor = .secondaryLabel
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

class AccountCell: UITableViewCell, ConfigurableTableViewCell {
	var account: AccountCellContent?
	lazy var accessoryButton: AccountCellButton = .init(cell: self)

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
		accessoryView = accessoryButton
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with viewModel: TableViewCellViewModel) {
		guard let viewModel = viewModel as? AccountCellContent else {
			return
		}
		configure(with: viewModel)
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
		accessoryButton.tintColor = .secondaryLabel
		contentConfiguration = content
	}
}
