//
//  TextFieldCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class TextFieldCell: TableViewCell {
	let textField: UITextField = {
		let textField = UITextField()
		textField.clearButtonMode = .whileEditing
		return textField
	}()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		textField.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(textField)
		NSLayoutConstraint.activate([
			textField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			textField.topAnchor.constraint(equalTo: topAnchor),
			textField.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func configure(with viewModel: TableViewCellViewModel) {
		super.configure(with: viewModel)
		guard let viewModel = viewModel as? TextFieldCellViewModel else {
			return
		}
		NotificationCenter.default
			.publisher(for: UITextField.textDidChangeNotification, object: textField)
			.map { ($0.object as? UITextField)?.text ?? "" }
			.debounce(for: .milliseconds(500), scheduler: RunLoop.main)
			.receive(on: RunLoop.main)
			.assign(to: \.input.value, on: viewModel)
			.store(in: &subscribers)
	}
}
