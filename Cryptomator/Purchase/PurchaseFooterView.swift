//
//  PurchaseFooterView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class PurchaseFooterView: UITableViewHeaderFooterView {
	lazy var restorePurchaseButton: UIButton = {
		let button = UIButton(type: .system)
		button.setTitle(LocalizedString.getValue("purchase.restorePurchase.button"), for: .normal)
		styleButton(button)
		return button
	}()

	private lazy var purchaseActionStack: UIStackView = {
		let stack = UIStackView(arrangedSubviews: [restorePurchaseButton])
		stack.alignment = .center
		return stack
	}()

	private lazy var legalBulletPoint = createBulletPointLabel()

	private lazy var legalInfoStack: UIStackView = {
		let stack = UIStackView(arrangedSubviews: [termsOfUseButton, legalBulletPoint, privacyPolicyButton])
		stack.alignment = .center
		return stack
	}()

	private lazy var termsOfUseButton: UIButton = {
		let button = HyperlinkButton(url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
		button.setTitle(LocalizedString.getValue("purchase.footer.termsOfUse"), for: .normal)
		styleButton(button)
		return button
	}()

	private lazy var privacyPolicyButton: UIButton = {
		let button = HyperlinkButton(url: URL(string: "https://cryptomator.org/privacy/")!)
		button.setTitle(LocalizedString.getValue("purchase.footer.privacyPolicy"), for: .normal)
		styleButton(button)
		return button
	}()

	private let font = UIFont.preferredFont(forTextStyle: .footnote)

	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		setupViews()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func setupViews() {
		let stack = UIStackView(arrangedSubviews: [purchaseActionStack, legalInfoStack])
		stack.axis = .vertical
		stack.alignment = .center
		stack.spacing = 32
		contentView.addSubview(stack)
		stack.translatesAutoresizingMaskIntoConstraints = false
		let stackBottomAnchor = stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		stackBottomAnchor.priority = .almostRequired
		NSLayoutConstraint.activate([
			stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 28),
			stackBottomAnchor,
			stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor),
			stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
			stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
		])
	}

	func configure(with traitCollection: UITraitCollection) {
		let preferredContentSize = traitCollection.preferredContentSizeCategory
		if preferredContentSize.isAccessibilityCategory {
			configureAsVerticalStack(purchaseActionStack)

			legalBulletPoint.isHidden = true
			configureAsVerticalStack(legalInfoStack)
		} else {
			configureAsHorizontalStack(purchaseActionStack)

			legalBulletPoint.isHidden = false
			configureAsHorizontalStack(legalInfoStack)
		}
	}

	private func configureAsVerticalStack(_ stack: UIStackView) {
		stack.axis = .vertical
		stack.spacing = 16
	}

	private func configureAsHorizontalStack(_ stack: UIStackView) {
		stack.axis = .horizontal
		stack.spacing = 5
	}

	private func styleButton(_ button: UIButton) {
		button.titleLabel?.font = font
		button.titleLabel?.adjustsFontSizeToFitWidth = true
		button.titleLabel?.adjustsFontForContentSizeCategory = true
		button.titleLabel?.minimumScaleFactor = 0.5
	}

	private func createBulletPointLabel() -> UILabel {
		let label = UILabel()
		label.text = "\u{2022}"
		label.font = font
		label.textColor = .secondaryLabel
		label.adjustsFontForContentSizeCategory = true
		return label
	}

	private class HyperlinkButton: UIButton {
		var primaryAction: (() -> Void)?
		convenience init(url: URL) {
			self.init(type: .system)
			setTitleColor(.cryptomatorPrimary, for: .normal)
			self.primaryAction = {
				UIApplication.shared.open(url)
			}
			addTarget(self, action: #selector(primaryActionTriggered), for: .primaryActionTriggered)
		}

		@objc private func primaryActionTriggered() {
			primaryAction?()
		}
	}
}
