//
//  LocalFileSystemAuthenticationViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import MobileCoreServices
import UIKit
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

class LocalFileSystemAuthenticationViewController: SingleSectionStaticUITableViewController, UIDocumentPickerDelegate {
	weak var coordinator: (LocalFileSystemAuthenticating & LocalVaultAdding & Coordinator)?
	private let viewModel: LocalFileSystemAuthenticationViewModelProtocol

	init(viewModel: LocalFileSystemAuthenticationViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	func openDocumentPicker() {
		let documentPicker: UIDocumentPickerViewController
		if #available(iOS 14, *) {
			documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
		} else {
			documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeFolder as String], in: .open)
		}
		documentPicker.allowsMultipleSelection = false
		documentPicker.delegate = self
		documentPicker.directoryURL = viewModel.documentPickerStartDirectoryURL
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

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return LargeHeaderFooterView(image: UIImage(named: "bot-vault"), infoText: viewModel.headerText)
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		openDocumentPicker()
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		guard let footerViewModel = viewModel.footerViewModel(for: section) else {
			return nil
		}
		let footerView = footerViewModel.viewType.init()
		footerView.configure(with: footerViewModel)
		footerView.tableView = tableView
		return footerView
	}
}
