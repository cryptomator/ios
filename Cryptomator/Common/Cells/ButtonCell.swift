//
//  ButtonCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class ButtonCell: UITableViewCell {
	lazy var button: UIButton = {
		let button = UIButton()
		button.setTitleColor(UIColor(named: "primary"), for: .normal)
		button.contentHorizontalAlignment = .leading
		return button
	}()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		button.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(button)
		NSLayoutConstraint.activate([
			button.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			button.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			button.topAnchor.constraint(equalTo: topAnchor),
			button.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
