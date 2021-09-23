//
//  PurchaseViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

class PurchaseViewController: UITableViewController {
	weak var coordinator: PurchaseCoordinator?

	private let viewModel: PurchaseViewModel

	init(viewModel: PurchaseViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = LocalizedString.getValue("purchase.title")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PurchaseCell")
		tableView.rowHeight = 44
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return viewModel.numberOfSections
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.numberOfRows(in: section)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "PurchaseCell", for: indexPath)
		cell.textLabel?.text = viewModel.title(for: indexPath)
		cell.textLabel?.textColor = viewModel.textColor(for: indexPath)
		cell.accessoryType = viewModel.accessoryType(for: indexPath)
		return cell
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return viewModel.footerTitle(for: section)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			return PurchaseHeaderView()
		} else {
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch viewModel.buttonAction(for: indexPath) {
		case .showUpgrade:
			coordinator?.showUpgrade()
		case .beginFreeTrial:
			coordinator?.beginFreeTrial()
		case .purchaseFullVersion:
			coordinator?.purchaseFullVersion()
		case .restorePurchase:
			coordinator?.restorePurchase()
		case .decideLater:
			coordinator?.close()
		}
	}
}

private class PurchaseHeaderView: UITableViewHeaderFooterView {
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
		infoLabel.text = LocalizedString.getValue("purchase.info")
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
