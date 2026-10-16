//
//  AddLocalVaultViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class AddLocalVaultViewController: LocalFileSystemAuthenticationViewController {
	typealias AddLocalVaultViewModel = LocalFileSystemAuthenticationViewModelProtocol & LocalFileSystemVaultInstallingViewModelProtocol
	let viewModel: AddLocalVaultViewModel

	init(viewModel: AddLocalVaultViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		let credential: LocalFileSystemCredential
		do {
			credential = try viewModel.userPicked(urls: urls)
		} catch {
			coordinator?.handleError(error, for: self)
			return
		}
		coordinator?.authenticated(credential: credential)
		Task {
			do {
				let result = try await viewModel.addVault(for: credential)
				coordinator?.showPasswordScreen(for: result)
			} catch {
				coordinator?.validationFailed(with: error, at: self)
			}
		}
	}
}
