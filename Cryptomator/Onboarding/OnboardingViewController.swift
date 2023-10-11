//
//  OnboardingViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

class OnboardingViewController: BaseUITableViewController {
	weak var coordinator: OnboardingCoordinator?

	private let viewModel: OnboardingViewModel

	init(viewModel: OnboardingViewModel) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = LocalizedString.getValue("onboarding.title")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "OnboardingCell")
	}

	func showIAP() {
		coordinator?.showIAP()
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return viewModel.numberOfSections
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.numberOfRows(in: section)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "OnboardingCell", for: indexPath)
		cell.textLabel?.text = viewModel.title(for: indexPath)
		cell.accessoryType = viewModel.accessoryType(for: indexPath)
		return cell
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return OnboardingHeaderView()
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch viewModel.buttonAction(for: indexPath) {
		case .showIAP:
			showIAP()
		case .unknown:
			break
		}
	}
}

private class OnboardingHeaderView: CryptoBotHeaderFooterView {
	init() {
		super.init(infoText: LocalizedString.getValue("onboarding.info"))
	}
}
