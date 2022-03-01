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

class IAPViewController<SectionType: Hashable, ButtonActionType: Hashable>: StaticUITableViewController<SectionType> {
	typealias IAPViewModel = BaseIAPViewModel<SectionType, ButtonActionType> & ProductFetching
	private let viewModel: IAPViewModel
	private weak var coordinator: Coordinator?
	private var subscriber: AnyCancellable?
	private var defaultIsModalInPresentation: Bool?

	init(viewModel: IAPViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		dataSource?.defaultRowAnimation = .fade
		defaultIsModalInPresentation = isModalInPresentation
		subscriber = viewModel.hasRunningTransaction.sink { [weak self] hasRunningTransaction in
			if hasRunningTransaction {
				self?.isModalInPresentation = true
				self?.disableNavigationBarItems()
			} else {
				self?.isModalInPresentation = self?.defaultIsModalInPresentation ?? false
				self?.enableNavigationBarItems()
			}
		}
		fetchProducts()
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

	func fetchProducts() {
		let viewModel = viewModel
		viewModel.fetchProducts().then { [weak self] in
			self?.applySnapshot(sections: viewModel.sections)
		}
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			return IAPHeaderView()
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
}

private class IAPHeaderView: UITableViewHeaderFooterView {
	private lazy var imageView: UIImageView = {
		let image = UIImage(named: "bot")
		let imageView = UIImageView(image: image)
		imageView.contentMode = .scaleAspectFit
		return imageView
	}()

	private lazy var features = HeaderFeatures(features: [
		"Write access to your vaults",
		"Open-source development",
		"Family sharing"
	])

	private lazy var separator: UIView = {
		let separator = UIView()
		separator.backgroundColor = .separator
		return separator
	}()

	private var separatorWeight: CGFloat {
		return 4.0 / UIScreen.main.scale
	}

	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		setupViews()
	}

	func setupViews() {
		contentView.addSubview(imageView)
		contentView.addSubview(features)
		contentView.addSubview(separator)

		imageView.translatesAutoresizingMaskIntoConstraints = false
		features.translatesAutoresizingMaskIntoConstraints = false
		separator.translatesAutoresizingMaskIntoConstraints = false

		let featuresTopAnchor = features.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 20)
		let separatorBottomAnchor = separator.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		featuresTopAnchor.priority = .almostRequired
		separatorBottomAnchor.priority = .almostRequired

		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: features.topAnchor, constant: 4),
			imageView.bottomAnchor.constraint(lessThanOrEqualTo: features.bottomAnchor, constant: -4),
			imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: features.leadingAnchor, constant: -20),
			imageView.widthAnchor.constraint(equalToConstant: 64),
			imageView.heightAnchor.constraint(equalToConstant: 64),

			featuresTopAnchor,
			features.trailingAnchor.constraint(equalTo: contentView.readableContentGuide.trailingAnchor),

			separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			separator.topAnchor.constraint(equalTo: features.layoutMarginsGuide.bottomAnchor, constant: 40),
			separator.heightAnchor.constraint(equalToConstant: separatorWeight),
			separatorBottomAnchor
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	class HeaderFeatures: UIView {
		private let textStyle: UIFont.TextStyle = .body
		private lazy var featureLabel: UILabel = {
			let label = UILabel()
			label.numberOfLines = 0
			label.font = .preferredFont(forTextStyle: textStyle)
			label.adjustsFontForContentSizeCategory = true
			return label
		}()

		override var intrinsicContentSize: CGSize {
			return featureLabel.intrinsicContentSize
		}

		init(features: [String]) {
			super.init(frame: .zero)
			featureLabel.attributedText = createAttributedString(from: features)
			setupViews()
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		private func setupViews() {
			featureLabel.translatesAutoresizingMaskIntoConstraints = false
			addSubview(featureLabel)
			NSLayoutConstraint.activate([
				featureLabel.topAnchor.constraint(equalTo: topAnchor),
				featureLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
				featureLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
				featureLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
			])
		}

		private func createAttributedString(from features: [String]) -> NSAttributedString {
			let configuration = UIImage.SymbolConfiguration(textStyle: textStyle)
			let imageAttachment = NSTextAttachment()
			imageAttachment.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)?.withTintColor(.cryptomatorPrimary)
			let attributedImageString = NSMutableAttributedString(attachment: imageAttachment)

			let indentation: CGFloat = (imageAttachment.image?.size.width ?? 15) + 5

			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.tabStops = [
				NSTextTab(textAlignment: .left, location: indentation, options: [:])
			]
			paragraphStyle.headIndent = indentation

			let attributedString = NSMutableAttributedString(string: "")

			features.enumerated().forEach {
				attributedString.append(attributedImageString)
				attributedString.append(NSAttributedString(string: "\t\($1)"))
				if $0 < features.count - 1 {
					attributedString.append(NSAttributedString(string: "\n"))
				}
			}

			attributedString.addAttributes(
				[.paragraphStyle: paragraphStyle],
				range: NSRange(location: 0, length: attributedString.length)
			)

			attributedString.addAttribute(.foregroundColor,
			                              value: UIColor.label,
			                              range: NSRange(location: 0, length: attributedString.length))
			attributedString.addAttribute(.font,
			                              value: UIFont.preferredFont(forTextStyle: textStyle),
			                              range: NSRange(location: 0, length: attributedString.length))
			return attributedString
		}
	}
}

protocol ProductFetching {
	func fetchProducts() -> Promise<Void>
}

class BaseIAPViewModel<SectionType: Hashable, ButtonActionType: Hashable>: TableViewModel<SectionType> {
	var headerTitle: String? { return nil }
	var hasRunningTransaction: AnyPublisher<Bool, Never> {
		return hasRunningTransactionPublisher.eraseToAnyPublisher()
	}

	private(set) var products = [ProductIdentifier: SKProduct]()
	private var fetchProductsStart: CFAbsoluteTime = 0.0
	private let minimumDisplayTime: TimeInterval = 1.0
	private lazy var hasRunningTransactionPublisher = PassthroughSubject<Bool, Never>()
	private var subscriber: AnyCancellable?

	private let iapManager: IAPManager
	private let storeManager: IAPStore

	init(storeManager: IAPStore, iapManager: IAPManager) {
		self.storeManager = storeManager
		self.iapManager = iapManager
		super.init()
		setupRunningTransactionSubscription()
	}

	func buyProduct(_ product: SKProduct, isLoadingBinding: Bindable<Bool>) -> Promise<PurchaseTransaction> {
		hasRunningTransactionPublisher.send(true)
		isLoadingBinding.value = true
		return iapManager.buy(product).recover { error -> PurchaseTransaction in
			if (error as? SKError)?.code == .paymentCancelled {
				throw PurchaseError.paymentCancelled
			} else {
				throw error
			}
		}.always {
			self.hasRunningTransactionPublisher.send(false)
			isLoadingBinding.value = false
		}
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
		}.delay(getDelay())
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
	func fetchProductsRecover() {}

	func restorePurchase(isLoadingBinding: Bindable<Bool>) -> Promise<RestoreTransactionsResult> {
		hasRunningTransactionPublisher.send(true)
		isLoadingBinding.value = true
		return iapManager.restore().recover { error -> RestoreTransactionsResult in
			if (error as? SKError)?.code == .paymentCancelled {
				throw PurchaseError.paymentCancelled
			} else {
				throw error
			}
		}.always {
			self.hasRunningTransactionPublisher.send(false)
			isLoadingBinding.value = false
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
		sections.forEach({ section in
			section.elements.forEach({
				if let buttonCellVM = $0 as? ButtonCellViewModel<ButtonActionType> {
					buttonCellVM.isEnabled.value = enabled
				}
			})
		})
	}
}
