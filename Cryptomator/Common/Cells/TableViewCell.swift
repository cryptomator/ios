//
//  TableViewCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

class TableViewCell: UITableViewCell, ConfigurableTableViewCell {
	lazy var subscribers = Set<AnyCancellable>()
//	private var viewModel: BindableTableViewCellViewModel?

	func configure(with viewModel: TableViewCellViewModel) {
//		self.viewModel = viewModel
		guard let viewModel = viewModel as? BindableTableViewCellViewModel else {
			return
		}
		bind(viewModel: viewModel)
	}

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func bind(viewModel: BindableTableViewCellViewModel) {
		viewModel.title.$value.assign(to: \.text, on: textLabel).store(in: &subscribers)
		viewModel.titleTextColor.$value.assign(to: \.textColor, on: textLabel).store(in: &subscribers)

		viewModel.detailTitle.$value.assign(to: \.text, on: detailTextLabel).store(in: &subscribers)
		viewModel.detailTitleTextColor.$value.assign(to: \.textColor, on: detailTextLabel).store(in: &subscribers)

		viewModel.image.$value.assign(to: \.image, on: imageView).store(in: &subscribers)
		viewModel.isEnabled.$value.assign(to: \.isUserInteractionEnabled, on: self).store(in: &subscribers)
		viewModel.selectionStyle.$value.assign(to: \.selectionStyle, on: self).store(in: &subscribers)
		viewModel.isEnabled.$value.sink(receiveValue: { [weak self] isEnabled in
			self?.textLabel?.textColor = isEnabled ? viewModel.titleTextColor.value : .label
			self?.contentView.alpha = isEnabled ? 1.0 : 0.25
		}).store(in: &subscribers)
		viewModel.accessoryType.$value.assign(to: \.accessoryType, on: self).store(in: &subscribers)
	}

	func removeAllBindings() {
		subscribers.forEach { $0.cancel() }
	}
}
