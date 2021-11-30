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

class PurchaseViewController: StaticUITableViewController<PurchaseSection> {
	weak var coordinator: PurchaseCoordinator?

	private let viewModel: PurchaseViewModel

	init(viewModel: PurchaseViewModel) {
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

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			return PurchaseHeaderView()
		} else {
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if section == 1 {
			// workaround to remove the header for the empty section (in combination with the missing bottom padding for the PurchaseHeaderView)
			// empty section is required to exclude the PurchaseHeaderView from the animated dataSource update
			return .leastNormalMagnitude
		} else {
			return UITableView.automaticDimension
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		switch viewModel.buttonAction(for: indexPath) {
		case .showUpgrade:
			coordinator?.showUpgrade()
		case .beginFreeTrial:
			viewModel.beginFreeTrial().then { [weak self] in
				self?.coordinator?.freeTrialStarted()
			}.catch { [weak self] error in
				self?.handleError(error)
			}
		case .purchaseFullVersion:
			viewModel.purchaseFullVersion().then { [weak self] in
				self?.coordinator?.fullVersionPurchased()
			}.catch { [weak self] error in
				self?.handleError(error)
			}
		case .restorePurchase:
			viewModel.restorePurchase().then { [weak self] result in
				self?.coordinator?.handleRestoreResult(result)
			}
		case .decideLater:
			coordinator?.close()
		case .unknown:
			break
		}
	}

	private func handleError(_ error: Error) {
		if case PurchaseError.paymentCancelled = error {
			return
		}
		coordinator?.handleError(error, for: self)
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

	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		configure()
	}

	func configure() {
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
			stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
