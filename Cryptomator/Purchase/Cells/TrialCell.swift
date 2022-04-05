//
//  TrialCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class TrialCell: IAPCell {
	private lazy var trialStatusLabel: UILabel = {
		let label = TrialStatusLabel()
		label.textColor = .secondaryLabel
		label.font = .preferredFont(forTextStyle: .headline)
		label.textAlignment = .center
		return label
	}()

	override var customAccessoryView: UIView? {
		return trialStatusLabel
	}

	func configure(with viewModel: TrialCellViewModel) {
		productTitleLabel.text = viewModel.productTitleText
		productDetailLabel.text = viewModel.expirationText
		trialStatusLabel.text = viewModel.status.localized
	}
}

class TrialStatusLabel: UILabel {
	private lazy var insets = UIEdgeInsets(top: 5, left: 15, bottom: 5, right: 15)
	override var text: String? {
		didSet {
			super.text = text?.uppercased()
		}
	}

	override func drawText(in rect: CGRect) {
		super.drawText(in: rect.inset(by: insets))
	}

	override var intrinsicContentSize: CGSize {
		var contentSize = super.intrinsicContentSize
		contentSize.height += insets.top + insets.bottom
		contentSize.width += insets.left + insets.right
		return contentSize
	}
}

enum TrialStatus: Hashable {
	case active
	case expired

	var localized: String {
		switch self {
		case .active:
			return LocalizedString.getValue("trialStatus.active")
		case .expired:
			return LocalizedString.getValue("trialStatus.expired")
		}
	}
}

struct TrialCellViewModel: Hashable {
	var status: TrialStatus {
		if expirationDate > Date() {
			return .active
		} else {
			return .expired
		}
	}

	let productTitleText = LocalizedString.getValue("purchase.product.trial")
	var expirationText: String {
		let formatter = DateFormatter()
		formatter.dateStyle = .short
		let formattedExpirationDate = formatter.string(for: expirationDate) ?? "Invalid Date"
		return String(format: LocalizedString.getValue("purchase.product.trial.expirationDate"), formattedExpirationDate)
	}

	let expirationDate: Date
}
