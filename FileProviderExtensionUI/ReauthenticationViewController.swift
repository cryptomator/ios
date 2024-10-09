//
//  ReauthenticationViewController.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 08.10.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class ReauthenticationViewController: UITableViewController {
	weak var coordinator: FileProviderCoordinator?
	private var vaultName: String

	private lazy var openCryptomatorCell: UITableViewCell = {
		let cell = UITableViewCell()
		cell.textLabel?.text = LocalizedString.getValue("fileProvider.onboarding.button.openCryptomator")
		cell.textLabel?.textColor = .cryptomatorPrimary
		return cell
	}()

	init(vaultName: String) {
		self.vaultName = vaultName
		super.init(style: .insetGrouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = vaultName
		let doneButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
		tableView.backgroundColor = .cryptomatorBackground
		tableView.cellLayoutMarginsFollowReadableWidth = true
	}

	@objc func done() {
		coordinator?.userCancelled()
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return openCryptomatorCell
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return ReauthenticationHeaderView(vaultName: vaultName)
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		coordinator?.openCryptomatorApp()
	}
}

private class ReauthenticationHeaderView: LargeHeaderFooterView {
	init(vaultName: String) {
		let config = UIImage.SymbolConfiguration(pointSize: 100)
		let symbolImage = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: config)?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)

		let infoText = String(format: LocalizedString.getValue("fileprovider.error.reauthentication"), vaultName)

		super.init(image: symbolImage, infoText: infoText)
	}
}

