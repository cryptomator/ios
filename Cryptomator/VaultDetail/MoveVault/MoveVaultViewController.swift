//
//  MoveVaultViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 26.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class MoveVaultViewController: ChooseFolderViewController {
	init(viewModel: MoveVaultViewModelProtocol) {
		super.init(with: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let chooseFolderButton = UIBarButtonItem(title: LocalizedString.getValue("vaultDetail.button.moveVault"), style: .done, target: self, action: #selector(chooseFolder))
		if let viewModel = viewModel as? MoveVaultViewModelProtocol {
			chooseFolderButton.isEnabled = viewModel.isAllowedToMove()
		}
		navigationItem.rightBarButtonItem = chooseFolderButton
	}

	override func showDetectedVault(_ vault: VaultDetailItem) {
		let failureView = DetectedVaultFailureView(text: LocalizedString.getValue("vaultDetail.moveVault.detectedMasterkey.text"))
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

	@objc private func chooseFolder() {
		guard let viewModel = viewModel as? MoveVaultViewModelProtocol else {
			return
		}
		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("vaultDetail.moveVault.progress")
		hud.show(presentingViewController: self)
		hud.showLoadingIndicator()
		viewModel.moveVault().then {
			hud.transformToSelfDismissingSuccess()
		}.then { [weak self] in
			self?.coordinator?.chooseItem(Folder(path: viewModel.cloudPath))
		}.catch { [weak self] error in
			self?.handleError(error, coordinator: self?.coordinator, progressHUD: hud)
		}
	}
}
