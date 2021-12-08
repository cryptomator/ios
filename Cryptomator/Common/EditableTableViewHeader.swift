//
//  EditableTableViewHeader.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class EditableTableViewHeader: UITableViewHeaderFooterView {
	lazy var editButton: UIButton = {
		let button = UIButton(type: .system)
		button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
		button.titleLabel?.adjustsFontForContentSizeCategory = true
		button.setTitle(LocalizedString.getValue("common.button.edit"), for: .normal)
		return button
	}()

	var isEditing: Bool = false {
		didSet {
			if oldValue != isEditing {
				changeEditButton()
			}
		}
	}

	private lazy var title: UILabel = {
		let label = UILabel()
		label.adjustsFontForContentSizeCategory = true
		label.font = .preferredFont(forTextStyle: .footnote)
		label.textColor = .secondaryLabel
		return label
	}()

	convenience init(title: String) {
		self.init()
		self.title.text = title.uppercased()
	}

	convenience init() {
		self.init(reuseIdentifier: nil)

		editButton.translatesAutoresizingMaskIntoConstraints = false
		title.translatesAutoresizingMaskIntoConstraints = false

		contentView.addSubview(editButton)
		contentView.addSubview(title)

		NSLayoutConstraint.activate([
			title.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			title.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			title.trailingAnchor.constraint(lessThanOrEqualTo: editButton.leadingAnchor, constant: -10),
			title.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
			title.centerYAnchor.constraint(equalTo: contentView.layoutMarginsGuide.centerYAnchor),

			editButton.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			editButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			editButton.centerYAnchor.constraint(equalTo: contentView.layoutMarginsGuide.centerYAnchor)
		])
	}

	private func changeEditButton() {
		UIView.performWithoutAnimation {
			editButton.setTitle(LocalizedString.getValue(isEditing ? "common.button.done" : "common.button.edit"), for: .normal)
			editButton.layoutIfNeeded()
		}
	}
}
