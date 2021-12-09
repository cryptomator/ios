//
//  LoadingCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 14.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class LoadingCell: UITableViewCell, ConfigurableTableViewCell {
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		accessoryType = .none
		let activityIndicatorView = UIActivityIndicatorView(style: .medium)
		activityIndicatorView.startAnimating()
		activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(activityIndicatorView)
		NSLayoutConstraint.activate([
			activityIndicatorView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor),
			activityIndicatorView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
			activityIndicatorView.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor),
			activityIndicatorView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor),
			activityIndicatorView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with viewModel: TableViewCellViewModel) {}
}

class LoadingCellViewModel: TableViewCellViewModel {
	override var type: ConfigurableTableViewCell.Type {
		LoadingCell.self
	}
}
