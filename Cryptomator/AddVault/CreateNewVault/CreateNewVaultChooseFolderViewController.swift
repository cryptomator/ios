//
//  CreateNewVaultChooseFolderViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class CreateNewVaultChooseFolderViewController: ChooseFolderViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		title = LocalizedString.getValue("addVault.createNewVault.title")
		let chooseFolderButton = UIBarButtonItem(title: LocalizedString.getValue("common.button.choose"), style: .done, target: self, action: #selector(chooseFolder))
		navigationItem.rightBarButtonItem = chooseFolderButton
	}

	override func showDetectedVault(_ vault: VaultDetailItem) {
		let failureView = DetectedVaultFailureView(text: LocalizedString.getValue("addVault.createNewVault.detectedMasterkey.text"))
		let containerView = UIView()
		failureView.translatesAutoresizingMaskIntoConstraints = false
		containerView.addSubview(failureView)
		NSLayoutConstraint.activate([
			failureView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
			failureView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
			failureView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			failureView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
		])

		// Prevents the view from being placed under the navigation bar
		tableView.backgroundView = containerView
		tableView.contentInsetAdjustmentBehavior = .never
		tableView.separatorStyle = .none

		navigationItem.rightBarButtonItem = nil
		navigationController?.setToolbarHidden(true, animated: true)
	}

	@objc func chooseFolder() {
		guard let viewModel = viewModel as? CreateNewVaultChooseFolderViewModelProtocol else {
			return
		}
		do {
			try coordinator?.chooseItem(viewModel.chooseCurrentFolder())
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}
}

#if DEBUG
import CryptomatorCloudAccessCore
import SwiftUI

private class CreateNewVaultChooseFolderViewModelMock: ChooseFolderViewModelProtocol {
	var headerTitle: String = "/Vault"

	let foundMasterkey = true
	let canCreateFolder: Bool
	let cloudPath: CloudPath
	let items: [CloudItemMetadata] = []

	init(cloudPath: CloudPath, canCreateFolder: Bool) {
		self.canCreateFolder = canCreateFolder
		self.cloudPath = cloudPath
	}

	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onVaultDetection: @escaping (VaultDetailItem) -> Void) {
		onChange()
	}

	func refreshItems() {}
}

struct CreateNewVaultChooseFolderVCPreview: PreviewProvider {
	static var previews: some View {
		let viewController = CreateNewVaultChooseFolderViewController(with: CreateNewVaultChooseFolderViewModelMock(cloudPath: CloudPath("/Vault"), canCreateFolder: false))
		let item = VaultDetailItem(name: "Vault", vaultPath: CloudPath("/Vault/masterkey.cryptomator"), isLegacyVault: false)
		viewController.showDetectedVault(item)
		return viewController.toPreview()
	}
}
#endif
