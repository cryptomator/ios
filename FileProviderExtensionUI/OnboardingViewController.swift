//
//  OnboardingViewController.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
class OnboardingViewController: UITableViewController {
	weak var coordinator: FileProviderCoordinator?

	private lazy var openCryptomatorCell: UITableViewCell = {
		let cell = UITableViewCell()
		cell.textLabel?.text = NSLocalizedString("onboarding.button.openCryptomator", comment: "")
		cell.textLabel?.textColor = UIColor(named: "primary")
		return cell
	}()

	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("onboarding.title", comment: "")
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
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

private class OnboardingHeaderView: UIView {
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
		super.init(frame: .zero)
		infoLabel.text = NSLocalizedString("onboarding.info", comment: "")
		let stack = UIStackView(arrangedSubviews: [imageView, infoLabel])
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.axis = .vertical
		stack.spacing = 20
		addSubview(stack)

		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor),
			stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
			stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
