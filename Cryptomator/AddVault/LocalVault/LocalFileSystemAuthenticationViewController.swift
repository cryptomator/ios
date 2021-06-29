//
//  LocalFileSystemAuthenticationViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import MobileCoreServices
import UIKit
class LocalFileSystemAuthenticationViewController: SingleSectionTableViewController, UIDocumentPickerDelegate {
	weak var coordinator: (LocalFileSystemAuthenticating & LocalVaultAdding & Coordinator)?
	private let viewModel: LocalFileSystemAuthenticationViewModelProtocol
	private lazy var openDocumentPickerCell: ButtonCell = {
		let cell = ButtonCell()
		cell.button.setTitle(viewModel.documentPickerButtonText, for: .normal)
		cell.button.addTarget(self, action: #selector(openDocumentPicker), for: .touchUpInside)
		return cell
	}()

	init(viewModel: LocalFileSystemAuthenticationViewModelProtocol) {
		self.viewModel = viewModel
		super.init()
	}

	@objc func openDocumentPicker() {
		let documentPicker: UIDocumentPickerViewController
		if #available(iOS 14, *) {
			documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
		} else {
			documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeFolder as String], in: .open)
		}
		documentPicker.allowsMultipleSelection = false
		documentPicker.delegate = self
		present(documentPicker, animated: true)
	}

	// MARK: - UIDocumentPickerDelegate

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		do {
			let credential = try viewModel.userPicked(urls: urls)
			coordinator?.authenticated(credential: credential)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return openDocumentPickerCell
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return LocalFileSystemAuthenticationHeaderView(text: viewModel.headerText)
	}
}

private class LocalFileSystemAuthenticationHeaderView: UIView {
	private lazy var image: UIImageView = {
		let image = UIImage(named: "bot-vault")
		let imageView = UIImageView(image: image)
		imageView.contentMode = .scaleAspectFit
		return imageView
	}()

	private lazy var infoText: UILabel = {
		let label = UILabel()
		label.textAlignment = .center
		label.numberOfLines = 0
		return label
	}()

	init(text: String) {
		super.init(frame: .zero)
		infoText.text = text
		let stack = UIStackView(arrangedSubviews: [image, infoText])
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.axis = .vertical
		stack.spacing = 20
		addSubview(stack)

		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
			stack.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor, constant: 12),
			stack.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: -12)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

#if DEBUG
import CryptomatorCommonCore
import SwiftUI
struct LocalFileSystemViewModelMock: LocalFileSystemAuthenticationViewModelProtocol {
	let documentPickerButtonText = "Select Storage Location"
	let headerText = "In the next screen, choose the storage location for your new vault."
	func userPicked(urls: [URL]) throws -> LocalFileSystemCredential {
		fatalError("Not mocked")
	}
}

struct LocalFileSystemAuthenticationVCPreview: PreviewProvider {
	static var previews: some View {
		LocalFileSystemAuthenticationViewController(viewModel: LocalFileSystemViewModelMock()).toPreview()
	}
}
#endif
