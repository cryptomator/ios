//
//  HeaderFooterViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

protocol HeaderFooterViewModel {
	var viewType: HeaderFooterViewModelConfiguring.Type { get }
	var title: Bindable<String?> { get }
}

protocol HeaderFooterViewModelConfiguring: UIView {
	func configure(with viewModel: HeaderFooterViewModel)
	var tableView: UITableView? { get set }
}

class BaseHeaderFooterViewModel: HeaderFooterViewModel {
	var viewType: HeaderFooterViewModelConfiguring.Type { return BaseHeaderFooterView.self }
	let title: Bindable<String?>

	init(title: String) {
		self.title = Bindable(title)
	}
}
