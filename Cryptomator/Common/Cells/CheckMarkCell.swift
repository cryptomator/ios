//
//  CheckMarkCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 14.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

class CheckMarkCell: UITableViewCell, ConfigurableTableViewCell {
	private var subscriber: AnyCancellable?

	func configure(with viewModel: TableViewCellViewModel) {
		guard let viewModel = viewModel as? CheckMarkCellViewModelType else {
			return
		}
		textLabel?.text = viewModel.title
		subscriber = viewModel.isSelected.$value.receive(on: DispatchQueue.main).sink { [weak self] isSelected in
			if isSelected {
				self?.accessoryType = .checkmark
			} else {
				self?.accessoryType = .none
			}
		}
	}
}

protocol CheckMarkCellViewModelType {
	var title: String? { get }
	var isSelected: Bindable<Bool> { get }
}
