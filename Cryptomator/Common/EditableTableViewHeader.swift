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

	private lazy var stack = UIStackView(arrangedSubviews: [title, editButton])

	convenience init(title: String) {
		self.init()
		self.title.text = title.uppercased()
	}

	convenience init() {
		self.init(reuseIdentifier: nil)

		title.setContentHuggingPriority(.defaultLow, for: .vertical)
		editButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
		stack.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(stack)
		let topAnchor = stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 20)
		topAnchor.priority = .almostRequired
		let bottomAnchor = stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		bottomAnchor.priority = .almostRequired
		NSLayoutConstraint.activate([
			topAnchor,
			bottomAnchor
		])
		NSLayoutConstraint.activate(stack.constraints(equalTo: contentView.layoutMarginsGuide, directions: [.horizontal]))
	}

	func configure(with traitCollection: UITraitCollection) {
		let preferredContentSize = traitCollection.preferredContentSizeCategory
		if preferredContentSize.isAccessibilityCategory {
			stack.axis = .vertical
			stack.alignment = .leading
		} else {
			stack.axis = .horizontal
			stack.alignment = .firstBaseline
		}
	}

	private func changeEditButton() {
		UIView.performWithoutAnimation {
			editButton.setTitle(LocalizedString.getValue(isEditing ? "common.button.done" : "common.button.edit"), for: .normal)
			editButton.layoutIfNeeded()
		}
	}
}
