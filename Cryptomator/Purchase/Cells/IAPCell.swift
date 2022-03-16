//
//  IAPCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import UIKit

class IAPCell: UITableViewCell {
	static let minimumHeight: CGFloat = 74

	lazy var productTitleLabel: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.numberOfLines = 0
		return label
	}()

	lazy var productDetailLabel: UILabel = {
		let label = AutoHidingLabel()
		label.font = .preferredFont(forTextStyle: .footnote)
		label.textColor = .secondaryLabel
		label.adjustsFontForContentSizeCategory = true
		label.numberOfLines = 0
		return label
	}()

	lazy var productTextStack: UIStackView = {
		let stack = UIStackView(arrangedSubviews: [productTitleLabel, productDetailLabel])
		stack.axis = .vertical
		stack.spacing = 5
		stack.alignment = .leading
		return stack
	}()

	var customAccessoryView: UIView? {
		return nil
	}

	lazy var stack = UIStackView(arrangedSubviews: [productTextStack, customAccessoryView].compactMap { $0 })

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		selectionStyle = .none
		setupViews()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func setupViews() {
		customAccessoryView?.setContentHuggingPriority(.defaultHigh, for: .horizontal)
		customAccessoryView?.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
		productTextStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		productTextStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

		stack.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
			stack.leadingAnchor.constraint(equalTo: contentView.readableContentGuide.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: contentView.readableContentGuide.trailingAnchor),
			contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: IAPCell.minimumHeight)
		])
	}

	func configure(with traitCollection: UITraitCollection) {
		let preferredContentSize = traitCollection.preferredContentSizeCategory
		if preferredContentSize.isAccessibilityCategory {
			stack.axis = .vertical
			stack.spacing = 5
			stack.alignment = .leading
		} else {
			stack.axis = .horizontal
			stack.spacing = 10
			stack.alignment = .center
			stack.distribution = .equalSpacing
		}
	}
}
