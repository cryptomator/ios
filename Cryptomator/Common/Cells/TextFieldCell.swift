//
//  TextFieldCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class TextFieldCell: TableViewCell, UITextFieldDelegate {
	lazy var textField: UITextField = {
		let textField = UITextField()
		textField.clearButtonMode = .whileEditing
		textField.delegate = self
		textField.font = .preferredFont(forTextStyle: .body)
		textField.adjustsFontForContentSizeCategory = true
		return textField
	}()

	private weak var viewModel: TextFieldCellViewModel?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		selectionStyle = .none
		textField.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(textField)
		NSLayoutConstraint.activate([
			textField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			textField.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			textField.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
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
		self.viewModel = viewModel
		textField.text = viewModel.input.value
		textField.placeholder = viewModel.placeholder
		if viewModel.isInitialFirstResponder {
			textField.becomeFirstResponder()
		}

		viewModel.startListeningToBecomeFirstResponder().sink { [weak self] in
			self?.textField.becomeFirstResponder()
		}.store(in: &subscribers)

		NotificationCenter.default
			.publisher(for: UITextField.textDidChangeNotification, object: textField)
			.map { ($0.object as? UITextField)?.text ?? "" }
			.receive(on: RunLoop.main)
			.assign(to: \.input.value, on: viewModel)
			.store(in: &subscribers)
		viewModel.input.$value.sink { [weak self] inputValue in
			self?.textField.text = inputValue
		}.store(in: &subscribers)
	}

	// MARK: - UITextFieldDelegate

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		viewModel?.returnButtonPressed()
		// Prevents adding a line break
		return false
	}
}
