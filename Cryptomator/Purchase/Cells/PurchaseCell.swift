//
//  PurchaseCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 24.02.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import UIKit

struct PurchaseCellViewModel {
	let productName: String
	let productDetail: String?
	let price: String
	let purchaseDetail: String?
	let purchaseButtonViewModel = PurchaseButtonViewModel()
}

struct PurchaseButtonViewModel {
	let isEnabled: Bindable<Bool> = Bindable(true)
	let isLoading: Bindable<Bool> = Bindable(false)
	var buttonTapped: AnyPublisher<Void, Never> {
		return buttonTappedPublisher.eraseToAnyPublisher()
	}

	fileprivate let buttonTappedPublisher = PassthroughSubject<Void, Never>()
}

class PurchaseCell: IAPCell {
	override var customAccessoryView: UIView? {
		return accessory
	}

	private let accessory = PurchaseCellAccessory()

	private lazy var subscribers = Set<AnyCancellable>()

	func configure(with viewModel: PurchaseCellViewModel) {
		productTitleLabel.text = viewModel.productName
		productDetailLabel.text = viewModel.productDetail
		accessory.button.setTitle(viewModel.price, for: .normal)
		accessory.detailLabel.text = viewModel.purchaseDetail
		accessory.configure(with: viewModel.purchaseButtonViewModel)
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		subscribers.removeAll()
		accessory.button.primaryAction = nil
	}
}

private class CapsuleButton: UIButton {
	override init(frame: CGRect) {
		super.init(frame: frame)

		contentEdgeInsets = .init(top: 5, left: 15, bottom: 5, right: 15)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		updateCornerRadius()
	}

	func updateCornerRadius() {
		layer.masksToBounds = true
		layer.cornerRadius = frame.size.height / 2
	}
}

private class PurchaseButton: CapsuleButton {
	var primaryAction: (() -> Void)?
	private var subscribers = Set<AnyCancellable>()

	convenience init() {
		self.init(type: .system)
		titleLabel?.font = .preferredFont(forTextStyle: .headline)
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		backgroundColor = .cryptomatorBackground
		titleLabel?.adjustsFontForContentSizeCategory = true
		setTitleColor(UIColor(named: "primary"), for: .normal)
		addTarget(self, action: #selector(primaryActionTriggered), for: .primaryActionTriggered)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc private func primaryActionTriggered() {
		primaryAction?()
	}

	func configure(with viewModel: PurchaseButtonViewModel) {
		viewModel.isEnabled.$value.receive(on: DispatchQueue.main).sink { [weak self] isEnabled in
			self?.isEnabled = isEnabled
		}.store(in: &subscribers)
		primaryAction = {
			viewModel.isLoading.value = true
			viewModel.buttonTappedPublisher.send()
			DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
				viewModel.isLoading.value = false
			}
		}
	}
}

private class PurchaseCellAccessory: UIStackView {
	lazy var loadingIndicator: UIActivityIndicatorView = {
		let indicator = UIActivityIndicatorView()
		indicator.hidesWhenStopped = true
		return indicator
	}()

	lazy var button = PurchaseButton()
	lazy var detailLabel: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .footnote)
		label.adjustsFontForContentSizeCategory = true
		label.textColor = .secondaryLabel
		label.textAlignment = .center
		label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		return label
	}()

	private var subscriber: AnyCancellable?

	override init(frame: CGRect) {
		super.init(frame: frame)
		addArrangedSubview(button)
		addArrangedSubview(detailLabel)
		axis = .vertical
		alignment = .center
		spacing = 5
	}

	@available(*, unavailable)
	required init(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with viewModel: PurchaseButtonViewModel) {
		button.configure(with: viewModel)
		subscriber = viewModel.isLoading.$value.receive(on: DispatchQueue.main).sink { [weak self] isLoading in
			if isLoading {
				self?.showLoadingOverlay()
			} else {
				self?.hideLoadingOverlay()
			}
		}
	}

	private func showLoadingOverlay() {
		addSubview(loadingIndicator)
		button.alpha = 0
		detailLabel.alpha = 0
		loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
			loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
		loadingIndicator.startAnimating()
	}

	private func hideLoadingOverlay() {
		button.alpha = 1
		detailLabel.alpha = 1
		loadingIndicator.removeFromSuperview()
	}
}

import SwiftUI

struct PurchaseButton_Previews: PreviewProvider {
	static var previews: some View {
		let button = PurchaseButton()
		button.setTitle("3.99€", for: .normal)
		return button.toPreview().frame(width: 80, height: 40, alignment: .center)
	}
}

struct PurchaseCellAccessory_Previews: PreviewProvider {
	static var previews: some View {
		let accessory = PurchaseCellAccessory()
		accessory.button.setTitle("11.99€", for: .normal)
		accessory.detailLabel.text = "Lifetime"
		return accessory.toPreview().frame(width: 100, height: 80, alignment: .center)
	}
}
