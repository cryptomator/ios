//
//  CreateNewVaultChooseFolderViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
class CreateNewVaultChooseFolderViewController: ChooseFolderViewController {
	init(viewModel: CreateNewVaultChooseFolderViewModelProtocol) {
		super.init(with: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("addVault.createNewVault.title", comment: "")
		let chooseFolderButton = UIBarButtonItem(title: NSLocalizedString("common.button.choose", comment: ""), style: .done, target: self, action: #selector(chooseFolder))
		navigationItem.rightBarButtonItem = chooseFolderButton

		let flexibleSpaceItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let createFolderButton = UIBarButtonItem(title: NSLocalizedString("common.button.createFolder", comment: ""), style: .plain, target: self, action: #selector(createNewFolder))
		createFolderButton.tintColor = UIColor(named: "primary")
		toolbarItems?.append(flexibleSpaceItem)
		toolbarItems?.append(createFolderButton)
	}

	override func showDetectedVault(_ vault: Item) {
		let failureView = FailureView()
		let containerView = UIView()
		failureView.translatesAutoresizingMaskIntoConstraints = false
		containerView.addSubview(failureView)
		NSLayoutConstraint.activate([
			failureView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
			failureView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
			failureView.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor),
			failureView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor)
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
			coordinator?.chooseItem(try viewModel.chooseCurrentFolder())
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}
}

private class FailureView: DetectedVaultView {
	init() {
		let configuration = UIImage.SymbolConfiguration(pointSize: 120)
		let warningSymbol = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: configuration)
		let imageView = UIImageView(image: warningSymbol)
		imageView.tintColor = UIColor(named: "triangleColor")
		super.init(imageView: imageView, text: NSLocalizedString("addVault.createNewVault.detectedMasterkey.text", comment: ""))
	}
}

#if DEBUG
import CryptomatorCloudAccessCore
import SwiftUI
struct FailureView_Preview: PreviewProvider {
	static var previews: some View {
		FailureView().toPreview()
	}
}

#endif
