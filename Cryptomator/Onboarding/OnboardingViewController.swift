//
//  OnboardingWelcomeViewController.swift
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
		tableView.rowHeight = 44
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

private class OnboardingHeaderView: UITableViewHeaderFooterView {
	private lazy var imageView: UIImageView = {
		let image = UIImage(named: "bot")
		let imageView = UIImageView(image: image)
		imageView.contentMode = .scaleAspectFit
		return imageView
	}()

	private lazy var infoLabel: UILabel = {
		let label = UILabel()
		label.textAlignment = .center
		label.numberOfLines = 0
		return label
	}()

	init() {
		super.init(reuseIdentifier: nil)
		infoLabel.text = LocalizedString.getValue("onboarding.info")
		let stack = UIStackView(arrangedSubviews: [imageView, infoLabel])
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.axis = .vertical
		stack.spacing = 20
		contentView.addSubview(stack)

		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 20),
			stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -20)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
