//
//  IAPViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class IAPViewController<T: Hashable>: StaticUITableViewController<T> {
	typealias IAPViewModel = BaseIAPViewModel & TableViewModel<T>
	private let viewModel: IAPViewModel
	private weak var coordinator: Coordinator?

	init(viewModel: IAPViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let viewModel = viewModel
		dataSource?.defaultRowAnimation = .fade
		viewModel.fetchProducts().then { [weak self] in
			self?.applySnapshot(sections: viewModel.sections)
		}
	}

	func setCoordinator(_ coordinator: Coordinator?) {
		self.coordinator = coordinator
	}

	func handleError(_ error: Error) {
		if case PurchaseError.paymentCancelled = error {
			return
		}
		coordinator?.handleError(error, for: self)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let headerView = IAPHeaderView()
			headerView.text = viewModel.headerTitle
			return headerView
		} else {
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if section == 1 {
			// workaround to remove the header for the empty section (in combination with the missing bottom padding for the IAPHeaderView)
			// empty section is required to exclude the IAPHeaderView from the animated dataSource update
			return .leastNormalMagnitude
		} else {
			return UITableView.automaticDimension
		}
	}
}

private class IAPHeaderView: UITableViewHeaderFooterView {
	var text: String? {
		get {
			infoLabel.text
		}
		set {
			infoLabel.text = newValue
		}
	}

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

	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		configure()
	}

	func configure() {
		let stack = UIStackView(arrangedSubviews: [imageView, infoLabel])
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.axis = .vertical
		stack.spacing = 20
		contentView.addSubview(stack)

		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 20),
			stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

import Promises

protocol BaseIAPViewModel {
	var headerTitle: String { get }
	func fetchProducts() -> Promise<Void>
}
