//
//  OpenExistingVaultPasswordViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import CryptomatorCryptoLib
import UIKit

class OpenExistingVaultPasswordViewController: SingleSectionStaticUITableViewController {
	weak var coordinator: (Coordinator & VaultInstalling)?
	lazy var verifyButton: UIBarButtonItem = {
		let button = UIBarButtonItem(title: LocalizedString.getValue("common.button.verify"), style: .done, target: self, action: #selector(verify))
		button.isEnabled = false
		return button
	}()

	private var viewModel: OpenExistingVaultPasswordViewModelProtocol

	private var viewToShake: UIView? {
		return navigationController?.view.superview // shake the whole modal dialog
	}

	private var subscribers = Set<AnyCancellable>()

	init(viewModel: OpenExistingVaultPasswordViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.rightBarButtonItem = verifyButton
		viewModel.enableVerifyButton.sink { [weak self] isEnabled in
			self?.verifyButton.isEnabled = isEnabled
		}.store(in: &subscribers)
		viewModel.lastReturnButtonPressed.sink { [weak self] in
			self?.verify()
		}.store(in: &subscribers)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		viewToShake?.cancelShaking()
	}

	@objc func verify() {
		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("addVault.openExistingVault.progress")
		hud.show(presentingViewController: self)
		hud.showLoadingIndicator()
		Task {
			do {
				try await viewModel.addVault()
				await hud.transformToSelfDismissingSuccess()
				coordinator?.showSuccessfullyAddedVault(withName: viewModel.vaultName, vaultUID: viewModel.vaultUID)
			} catch {
				await hud.dismiss(animated: true)
				handleError(error)
			}
		}
	}

	// MARK: - Internal

	private func handleError(_ error: Error) {
		if case MasterkeyFileError.invalidPassphrase = error {
			viewToShake?.shake()
		} else {
			coordinator?.handleError(error, for: self)
		}
	}
}

#if DEBUG
import Combine
import SwiftUI

private class OpenExistingVaultMasterkeyProcessingViewModelMock: SingleSectionTableViewModel, OpenExistingVaultPasswordViewModelProtocol {
	var enableVerifyButton: AnyPublisher<Bool, Never> {
		Just(false).eraseToAnyPublisher()
	}

	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		PassthroughSubject<Void, Never>().eraseToAnyPublisher()
	}

	let vaultUID = ""

	var password: String?
	var footerTitle: String {
		"Enter password for \"\(vaultName)\""
	}

	let vaultName = "Work"

	func addVault() async throws {}

	override func getFooterTitle(for section: Int) -> String? {
		return footerTitle
	}
}

struct OpenExistingVaultMasterkeyProcessingVC_Preview: PreviewProvider {
	static var previews: some View {
		OpenExistingVaultPasswordViewController(viewModel: OpenExistingVaultMasterkeyProcessingViewModelMock()).toPreview()
	}
}
#endif
