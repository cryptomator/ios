//
//  PurchaseStatusCell.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 20.11.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import UIKit

class PurchaseStatusCell: UITableViewCell, ConfigurableTableViewCell {
	private let iconImageView = UIImageView()
	private let titleLabel = UILabel()
	private let subtitleLabel = UILabel()
	lazy var subscribers = Set<AnyCancellable>()

	func configure(with viewModel: TableViewCellViewModel) {
		removeAllBindings()
		guard let viewModel = viewModel as? PurchaseStatusCellViewModel else {
			return
		}
		iconImageView.image = UIImage(systemName: viewModel.iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))
		viewModel.title.$value.assign(to: \.text, on: titleLabel).store(in: &subscribers)
		viewModel.subtitle.$value.assign(to: \.text, on: subtitleLabel).store(in: &subscribers)
		accessoryType = .disclosureIndicator
		selectionStyle = .default
	}

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)

		iconImageView.translatesAutoresizingMaskIntoConstraints = false
		iconImageView.contentMode = .scaleAspectFit
		iconImageView.tintColor = .cryptomatorPrimary

		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.font = .preferredFont(forTextStyle: .body)
		titleLabel.textColor = .label
		titleLabel.numberOfLines = 0

		subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
		subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
		subtitleLabel.textColor = .secondaryLabel
		subtitleLabel.numberOfLines = 0

		contentView.addSubview(iconImageView)
		contentView.addSubview(titleLabel)
		contentView.addSubview(subtitleLabel)

		NSLayoutConstraint.activate([
			iconImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			iconImageView.widthAnchor.constraint(equalToConstant: 29),
			iconImageView.heightAnchor.constraint(equalToConstant: 29),

			titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),
			titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
			titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

			subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
			subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
			subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
			subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -11)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func removeAllBindings() {
		subscribers.forEach { $0.cancel() }
	}
}
