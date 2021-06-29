//
//  OpenExistingVaultChooseFolderViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

class OpenExistingVaultChooseFolderViewController: ChooseFolderViewController {
	private var vault: VaultDetailItem?

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("addVault.openExistingVault.title", comment: "")
		tableView.register(ButtonCell.self, forCellReuseIdentifier: "ButtonCell")
	}

	override func showDetectedVault(_ vault: VaultDetailItem) {
		tableView.reloadData()
		self.vault = vault
		refreshControl = nil
		navigationController?.setToolbarHidden(true, animated: true)
	}

	@objc func addVault() {
		guard let vault = vault else {
			return
		}
		coordinator?.chooseItem(vault)
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if viewModel.foundMasterkey {
			return 1
		} else {
			return super.tableView(tableView, numberOfRowsInSection: section)
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if viewModel.foundMasterkey {
			// swiftlint:disable:next force_cast
			let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell", for: indexPath) as! ButtonCell
			cell.button.setTitle(NSLocalizedString("addVault.openExistingVault.detectedMasterkey.add", comment: ""), for: .normal)
			cell.button.addTarget(self, action: #selector(addVault), for: .touchUpInside)
			return cell
		} else {
			return super.tableView(tableView, cellForRowAt: indexPath)
		}
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if viewModel.foundMasterkey, let vault = vault {
			return SuccessView(vaultName: vault.name)
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if viewModel.foundMasterkey {
			// do nothing
		} else {
			super.tableView(tableView, didSelectRowAt: indexPath)
		}
	}
}

private class SuccessView: DetectedVaultView {
	init(vaultName: String) {
		let botVaultImage = UIImage(named: "bot-vault")
		let imageView = UIImageView(image: botVaultImage)
		let text = String(format: NSLocalizedString("addVault.openExistingVault.detectedMasterkey.text", comment: ""), vaultName)
		super.init(imageView: imageView, text: text)
	}
}

#if DEBUG
import SwiftUI

private class OpenExistingVaultChooseFolderViewModelMock: ChooseFolderViewModelProtocol {
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

struct OpenExistingVaultChooseFolderVCPreview: PreviewProvider {
	static var previews: some View {
		let viewController = OpenExistingVaultChooseFolderViewController(with: OpenExistingVaultChooseFolderViewModelMock(cloudPath: CloudPath("/Vault"), canCreateFolder: false))
		let item = VaultDetailItem(name: "vault", vaultPath: CloudPath("/Vault/masterkey.cryptomator"), isLegacyVault: false)
		viewController.showDetectedVault(item)
		return viewController.toPreview()
	}
}
#endif
