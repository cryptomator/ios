//
//  PurchaseViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class PurchaseViewController: IAPViewController {
	private let viewModel: PurchaseViewModel
	private lazy var footerView: PurchaseFooterView = {
		let footerView = PurchaseFooterView()
		footerView.restorePurchaseButton.addTarget(self, action: #selector(restorePurchase), for: .primaryActionTriggered)
		return footerView
	}()

	init(viewModel: PurchaseViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		viewModel.hasRunningTransaction.receive(on: DispatchQueue.main).sink { [weak self] hasRunningTransaction in
			self?.footerView.restorePurchaseButton.isEnabled = !hasRunningTransaction
		}.store(in: &subscribers)
	}

	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		if let parentFooterView = super.tableView(tableView, viewForFooterInSection: section) {
			return parentFooterView
		}
		let itemIdentifier = dataSource?.itemIdentifier(for: IndexPath(row: 0, section: section))
		if itemIdentifier == .loadingCell {
			return nil
		}
		footerView.configure(with: tableView.traitCollection)
		return footerView
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		super.tableView(tableView, didSelectRowAt: indexPath)
		guard let itemIdentifier = dataSource?.itemIdentifier(for: indexPath) else {
			return
		}
		if case Item.showUpgradeOffer = itemIdentifier {
			coordinator?.showUpgrade(onAlertDismiss: {
				tableView.deselectRow(at: indexPath, animated: true)
			})
		}
	}

	@objc private func restorePurchase() {
		viewModel.restorePurchase().then { [weak self] result in
			self?.coordinator?.handleRestoreResult(result)
		}.catch { [weak self] error in
			self?.handleError(error)
		}
	}
}
