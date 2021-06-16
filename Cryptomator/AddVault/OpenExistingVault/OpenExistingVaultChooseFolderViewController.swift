//
//  OpenExistingVaultChooseFolderViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import UIKit

class OpenExistingVaultChooseFolderViewController: ChooseFolderViewController {
	private var vault: Item?

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("addVault.openExistingVault.title", comment: "")
	}

	override func showDetectedVault(_ vault: Item) {
		self.vault = vault
		let successView = SuccessView(viewModel: DetectedMasterkeyViewModel(masterkeyPath: vault.path))
		let containerView = UIView()
		successView.translatesAutoresizingMaskIntoConstraints = false
		containerView.addSubview(successView)
		NSLayoutConstraint.activate([
			successView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
			successView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
			successView.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor),
			successView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor)
		])

		// Prevents the view from being placed under the navigation bar
		tableView.backgroundView = containerView
		tableView.contentInsetAdjustmentBehavior = .never
		tableView.separatorStyle = .none

		let addVaultButton = UIBarButtonItem(title: NSLocalizedString("common.button.add", comment: ""), style: .done, target: self, action: #selector(addVault))
		navigationItem.rightBarButtonItem = addVaultButton
		navigationController?.setToolbarHidden(true, animated: true)
	}

	@objc func addVault() {
		guard let vault = vault else {
			return
		}
		coordinator?.chooseItem(vault)
	}
}

private class SuccessView: UIView {
	lazy var label: UILabel = {
		let label = UILabel()
		label.numberOfLines = 0
		label.lineBreakMode = .byWordWrapping
		label.textAlignment = .center
		return label
	}()

	convenience init(viewModel: DetectedMasterkeyViewModel) {
		self.init(frame: .zero)

		let botVaultImage = UIImage(named: "bot-vault")
		let imageView = UIImageView(image: botVaultImage)

		imageView.contentMode = .scaleAspectFit

		label.text = viewModel.text

		imageView.translatesAutoresizingMaskIntoConstraints = false
		label.translatesAutoresizingMaskIntoConstraints = false

		addSubview(imageView)
		addSubview(label)

		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: topAnchor),
			imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
			label.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
			label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
			label.bottomAnchor.constraint(equalTo: bottomAnchor),
			label.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor)
		])
	}
}
