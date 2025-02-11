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

struct PurchaseCellViewModel: Hashable {
	let productName: String
	let price: String
	let purchaseDetail: String?
	let purchaseButtonViewModel = PurchaseButtonViewModel()
	let productIdentifier: ProductIdentifier
}

struct PurchaseButtonViewModel: Hashable {
	let isEnabled: Bindable<Bool> = Bindable(true)
	let isLoading: Bindable<Bool> = Bindable(false)
}

class PurchaseCell: IAPCell {
	var purchaseButton: PurchaseButton {
		return accessory.button
	}

	override var customAccessoryView: UIView? {
		return accessory
	}

	private let accessory = PurchaseCellAccessory()

	func configure(with viewModel: PurchaseCellViewModel) {
		productTitleLabel.text = viewModel.productName
		accessory.button.setTitle(viewModel.price, for: .normal)
		accessory.detailLabel.text = viewModel.purchaseDetail
		accessory.configure(with: viewModel.purchaseButtonViewModel)
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		purchaseButton.primaryAction = nil
	}
}

class CapsuleButton: UIButton {
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

class PurchaseButton: CapsuleButton {
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
		setTitleColor(.cryptomatorPrimary, for: .normal)
		setTitleColor(.secondaryLabel, for: .disabled)
		addTarget(self, action: #selector(primaryActionTriggered), for: .primaryActionTriggered)
		widthAnchor.constraint(greaterThanOrEqualToConstant: 85).isActive = true
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
	}

	// Expand the buttons hit area to its superview bounds
	override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
		superview?.bounds.contains(point) ?? bounds.contains(point)
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
