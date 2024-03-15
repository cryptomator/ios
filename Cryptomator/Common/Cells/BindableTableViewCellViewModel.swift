//
//  BindableTableViewCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class BindableTableViewCellViewModel: TableViewCellViewModel {
	override var type: ConfigurableTableViewCell.Type {
		return TableViewCell.self
	}

	var title: Bindable<String?>
	var titleTextColor: Bindable<UIColor?>
	var detailTitle: Bindable<String?>
	var detailTitleTextColor: Bindable<UIColor?>
	var image: Bindable<UIImage?>
	var isEnabled: Bindable<Bool>
	let selectionStyle: Bindable<UITableViewCell.SelectionStyle>
	let accessoryType: Bindable<UITableViewCell.AccessoryType>

	init(title: String? = nil, titleTextColor: UIColor? = nil, detailTitle: String? = nil, detailTitleTextColor: UIColor? = .secondaryLabel, image: UIImage? = nil, isEnabled: Bool = true, selectionStyle: UITableViewCell.SelectionStyle = .none, accessoryType: UITableViewCell.AccessoryType = .none) {
		self.title = Bindable(title)
		self.titleTextColor = Bindable(titleTextColor)
		self.detailTitle = Bindable(detailTitle)
		self.detailTitleTextColor = Bindable(detailTitleTextColor)
		self.image = Bindable(image)
		self.isEnabled = Bindable(isEnabled)
		self.selectionStyle = Bindable(selectionStyle)
		self.accessoryType = Bindable(accessoryType)
	}
}

class TableViewCellViewModel: Hashable {
	var type: ConfigurableTableViewCell.Type {
		fatalError("not implemented")
	}

	private let identifier = UUID()

	static func == (lhs: TableViewCellViewModel, rhs: TableViewCellViewModel) -> Bool {
		return lhs.identifier == rhs.identifier
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(identifier)
	}
}

protocol ConfigurableTableViewCell: UITableViewCell {
	func configure(with viewModel: TableViewCellViewModel)
}

import Combine

protocol ViewModel {
	var error: AnyPublisher<Error, Never> { get }
}
