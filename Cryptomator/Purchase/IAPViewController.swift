//
//  IAPViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Foundation
import Promises
import StoreKit
import UIKit

class IAPViewController: BaseUITableViewController {
	enum Section {
		case main
	}

	enum Item: Hashable {
		case retryButton
		case showUpgradeOffer
		case purchaseCell(PurchaseCellViewModel)
		case trialCell(TrialCellViewModel)
		case loadingCell
	}

	typealias IAPViewModel = BaseIAPViewModel & ProductFetching
	var dataSource: UITableViewDiffableDataSource<Section, Item>?
	lazy var subscribers = Set<AnyCancellable>()
	weak var coordinator: PurchaseCoordinator?
	private let viewModel: IAPViewModel
	private var defaultIsModalInPresentation: Bool?

	init(viewModel: IAPViewModel) {
		self.viewModel = viewModel
		super.init(style: .insetGrouped)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		configureDataSource()
		tableView.delaysContentTouches = false
		dataSource?.defaultRowAnimation = .fade
		defaultIsModalInPresentation = isModalInPresentation
		viewModel.hasRunningTransaction.sink { [weak self] hasRunningTransaction in
			if hasRunningTransaction {
				self?.isModalInPresentation = true
				self?.disableNavigationBarItems()
			} else {
				self?.isModalInPresentation = self?.defaultIsModalInPresentation ?? false
				self?.enableNavigationBarItems()
			}
		}.store(in: &subscribers)
		applySnapshot(viewModel.cells, animatingDifferences: false)
		fetchProducts()
	}

	func handleError(_ error: Error) {
		if case PurchaseError.paymentCancelled = error {
			return
		}
		coordinator?.handleError(error, for: self)
	}

	func fetchProducts() {
		let viewModel = viewModel
		viewModel.fetchProducts().then { [weak self] in
			self?.applySnapshot(viewModel.cells)
		}
	}

	func applySnapshot(_ items: [Item], animatingDifferences: Bool = true) {
		var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
		snapshot.appendSections([.main])
		snapshot.appendItems(items)
		dataSource?.apply(snapshot, animatingDifferences: tableView.window != nil ? animatingDifferences : false)
	}

	func configureDataSource() {
		dataSource = UITableViewDiffableDataSource<Section, Item>(tableView: tableView, cellProvider: { tableView, _, itemIdentifier in
			let cell: UITableViewCell
			switch itemIdentifier {
			case let .purchaseCell(purchaseCellViewModel):
				let purchaseCell = PurchaseCell()
				purchaseCell.configure(with: purchaseCellViewModel)
				purchaseCell.configure(with: tableView.traitCollection)
				purchaseCell.purchaseButton.primaryAction = { [weak self] in
					self?.buyProduct(purchaseCellViewModel.productIdentifier)
				}
				cell = purchaseCell
			case let .trialCell(trialCellViewModel):
				let trialCell = TrialCell()
				trialCell.configure(with: trialCellViewModel)
				trialCell.configure(with: tableView.traitCollection)
				cell = trialCell
			case .retryButton:
				cell = UITableViewCell()
				cell.textLabel?.text = LocalizedString.getValue("purchase.retry.button")
				cell.textLabel?.textColor = .cryptomatorPrimary
				cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: IAPCell.minimumHeight).isActive = true
			case .showUpgradeOffer:
				let disclosureCell = DisclosureCell()
				disclosureCell.textLabel?.text = LocalizedString.getValue("upgrade.title")
				cell = disclosureCell
			case .loadingCell:
				cell = LoadingCell()
				cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: IAPCell.minimumHeight).isActive = true
			}
			return cell
		})
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let header = IAPHeaderView()
		header.infoLabel.attributedText = viewModel.infoText
		return header
	}

	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		guard let itemIdentifier = dataSource?.itemIdentifier(for: IndexPath(row: 0, section: section)), itemIdentifier == .retryButton else {
			return nil
		}
		let footer = UITableViewHeaderFooterView()
		footer.textLabel?.text = LocalizedString.getValue("purchase.retry.footer")
		return footer
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let itemIdentifier = dataSource?.itemIdentifier(for: indexPath), itemIdentifier == .retryButton else {
			return
		}
		viewModel.showLoadingCell()
		var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
		snapshot.appendSections([.main])
		snapshot.appendItems(viewModel.cells)
		dataSource?.apply(snapshot, animatingDifferences: false, completion: {
			// reload sections without animation in order to refresh the footer
			snapshot.reloadSections([.main])
			self.dataSource?.apply(snapshot, animatingDifferences: false)
		})
		fetchProducts()
	}

	private func disableNavigationBarItems() {
		navigationItem.hidesBackButton = true
		setEnabledFlagForNavigationBarItems(to: false)
	}

	private func enableNavigationBarItems() {
		navigationItem.hidesBackButton = false
		setEnabledFlagForNavigationBarItems(to: true)
	}

	private func setEnabledFlagForNavigationBarItems(to enabled: Bool) {
		setEnabledFlagForBarButtonItems(navigationItem.leftBarButtonItems, to: enabled)
		setEnabledFlagForBarButtonItems(navigationItem.rightBarButtonItems, to: enabled)
	}

	private func setEnabledFlagForBarButtonItems(_ barButtonItems: [UIBarButtonItem]?, to enabled: Bool) {
		barButtonItems?.forEach({ $0.isEnabled = enabled })
	}

	private func buyProduct(_ productIdentifier: ProductIdentifier) {
		viewModel.buyProduct(productIdentifier).then { [weak self] transaction in
			self?.successfulPurchase(transaction: transaction)
		}.catch { [weak self] error in
			self?.handleError(error)
		}
	}

	private func successfulPurchase(transaction: PurchaseTransaction) {
		switch transaction {
		case .fullVersion:
			coordinator?.fullVersionPurchased()
		case let .freeTrial(trialExpirationDate):
			coordinator?.freeTrialStarted(expirationDate: trialExpirationDate)
		case .yearlySubscription:
			coordinator?.fullVersionPurchased()
		case .unknown:
			break
		}
	}
}

protocol ProductFetching {
	func fetchProducts() -> Promise<Void>
}

class BaseIAPViewModel {
	typealias Item = IAPViewController.Item

	var title: String? { return nil }
	var infoText: NSAttributedString? { return nil }
	var cells = [Item.loadingCell]
	var hasRunningTransaction: AnyPublisher<Bool, Never> {
		return hasRunningTransactionPublisher.eraseToAnyPublisher()
	}

	private(set) var products = [ProductIdentifier: SKProduct]()
	private var fetchProductsStart: CFAbsoluteTime = 0.0
	private let minimumDisplayTime: TimeInterval
	private lazy var hasRunningTransactionPublisher = PassthroughSubject<Bool, Never>()
	private var subscriber: AnyCancellable?

	private let iapManager: IAPManager
	private let storeManager: IAPStore

	init(storeManager: IAPStore = StoreManager.shared, iapManager: IAPManager = StoreObserver.shared, minimumDisplayTime: TimeInterval = 1.0) {
		self.storeManager = storeManager
		self.iapManager = iapManager
		self.minimumDisplayTime = minimumDisplayTime
		setupRunningTransactionSubscription()
	}

	func buyProduct(_ productIdentifier: ProductIdentifier) -> Promise<PurchaseTransaction> {
		guard let product = products[productIdentifier] else {
			return Promise(PurchaseError.unavailableProduct)
		}
		hasRunningTransactionPublisher.send(true)
		setIsLoading(to: true, forCellWith: productIdentifier)
		return iapManager.buy(product).recover { error -> PurchaseTransaction in
			if (error as? SKError)?.code == .paymentCancelled {
				throw PurchaseError.paymentCancelled
			} else if (error as? SKError)?.code == .unknown {
				throw PurchaseError.unknown
			} else {
				throw error
			}
		}.always {
			self.hasRunningTransactionPublisher.send(false)
			self.setIsLoading(to: false, forCellWith: productIdentifier)
		}
	}

	func showLoadingCell() {
		cells.removeAll()
		cells.append(.loadingCell)
	}

	func fetchProducts(with identifiers: [ProductIdentifier]) -> Promise<Void> {
		fetchProductsStart = CFAbsoluteTimeGetCurrent()
		return storeManager.fetchProducts(with: identifiers).then { response in
			self.products = response.products.reduce(into: [ProductIdentifier: SKProduct]()) {
				guard let productIdentifier = ProductIdentifier(rawValue: $1.productIdentifier) else {
					return
				}
				$0[productIdentifier] = $1
			}
		}.then { _ -> Void in
			self.fetchProductsSuccess()
		}.recover { _ -> Void in
			self.fetchProductsRecover()
		}.delay(getDelay()).always {
			self.removeLoadingItem()
		}
	}

	/**
	 Called when `storeManager.fetchProducts(with:)` succeeds.
	 You can implement this method in your subclass if you want to perform further actions in this case.
	 */
	func fetchProductsSuccess() {}

	/**
	 Called when `storeManager.fetchProducts(with:)` fails.
	 You can implement this method in your subclass if you want to perform further actions in this case.
	 */
	func fetchProductsRecover() {
		addRetryItem()
	}

	func restorePurchase() -> Promise<RestoreTransactionsResult> {
		hasRunningTransactionPublisher.send(true)
		return iapManager.restore().recover { error -> RestoreTransactionsResult in
			if (error as? SKError)?.code == .paymentCancelled {
				throw PurchaseError.paymentCancelled
			} else if (error as? SKError)?.code == .unknown {
				throw PurchaseError.unknown
			} else {
				throw error
			}
		}.always {
			self.hasRunningTransactionPublisher.send(false)
		}
	}

	private func getDelay() -> TimeInterval {
		if fetchProductsStart > 0 {
			return fetchProductsStart - CFAbsoluteTimeGetCurrent() + minimumDisplayTime
		} else {
			return 0
		}
	}

	private func setupRunningTransactionSubscription() {
		subscriber = hasRunningTransaction.sink(receiveValue: { [weak self] hasRunningTransaction in
			if hasRunningTransaction {
				self?.disableAllButtonCellViewModels()
			} else {
				self?.enableAllButtonCellViewModels()
			}
		})
	}

	private func disableAllButtonCellViewModels() {
		setEnabledFlagForAllButtonCellViewModels(to: false)
	}

	private func enableAllButtonCellViewModels() {
		setEnabledFlagForAllButtonCellViewModels(to: true)
	}

	private func setEnabledFlagForAllButtonCellViewModels(to enabled: Bool) {
		for cell in cells {
			if case let Item.purchaseCell(purchaseCellViewModel) = cell {
				purchaseCellViewModel.purchaseButtonViewModel.isEnabled.value = enabled
			}
		}
	}

	private func setIsLoading(to isLoading: Bool, forCellWith productIdentifier: ProductIdentifier) {
		for cell in cells {
			if case let Item.purchaseCell(purchaseCellViewModel) = cell, purchaseCellViewModel.productIdentifier == productIdentifier {
				purchaseCellViewModel.purchaseButtonViewModel.isLoading.value = isLoading
			}
		}
	}

	private func removeLoadingItem() {
		if let index = cells.firstIndex(where: { $0 == Item.loadingCell }) {
			cells.remove(at: index)
		}
	}

	private func addRetryItem() {
		cells.append(.retryButton)
	}
}
