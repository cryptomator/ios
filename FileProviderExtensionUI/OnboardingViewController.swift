//
//  OnboardingViewController.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class OnboardingViewController: UITableViewController {
	weak var coordinator: FileProviderCoordinator?

	private lazy var openCryptomatorCell: UITableViewCell = {
		let cell = UITableViewCell()
		cell.textLabel?.text = LocalizedString.getValue("fileProvider.onboarding.button.openCryptomator")
		cell.textLabel?.textColor = .cryptomatorPrimary
		return cell
	}()

	init() {
		super.init(style: .insetGrouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = LocalizedString.getValue("fileProvider.onboarding.title")
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
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
		return OnboardingHeaderView()
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		coordinator?.openCryptomatorApp()
	}
}

private class OnboardingHeaderView: CryptoBotHeaderFooterView {
	init() {
		super.init(infoText: LocalizedString.getValue("fileProvider.onboarding.info"))
	}
}
