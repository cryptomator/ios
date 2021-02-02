//
//  EditableTableViewHeader.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
class EditableTableViewHeader: UITableViewHeaderFooterView {
	let editButton = UIButton(type: .system)
	let title = UILabel()
	var isEditing: Bool = false {
		didSet {
			if oldValue != isEditing {
				changeEditButton()
			}
		}
	}

	convenience init(title: String) {
		self.init()
		self.title.text = title.uppercased()
		editButton.setTitle("Edit", for: .normal)
	}

	convenience init() {
		self.init(reuseIdentifier: nil)

		editButton.setTitleColor(UIColor(named: "primary"), for: .normal)
		editButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)

		title.font = UIFont.preferredFont(forTextStyle: .footnote)
		if #available(iOS 13, *) {
			title.textColor = .secondaryLabel
		} else {
			title.textColor = UIColor(named: "secondaryLabel")
		}

		editButton.translatesAutoresizingMaskIntoConstraints = false
		title.translatesAutoresizingMaskIntoConstraints = false

		contentView.addSubview(editButton)
		contentView.addSubview(title)

		NSLayoutConstraint.activate([
			title.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			title.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
			title.heightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.heightAnchor),

			editButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			editButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
			editButton.heightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.heightAnchor)

		])
	}

	private func changeEditButton() {
		UIView.performWithoutAnimation {
			editButton.setTitle(isEditing ? "Done" : "Edit", for: .normal)
			editButton.layoutIfNeeded()
		}
	}
}
