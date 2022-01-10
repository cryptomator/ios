//
//  BaseHeaderFooterView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

class BaseHeaderFooterView: UITableViewHeaderFooterView, HeaderFooterViewModelConfiguring {
	weak var tableView: UITableView?

	var subscriber: AnyCancellable?

	func configure(with viewModel: HeaderFooterViewModel) {
		textLabel?.numberOfLines = 0
		textLabel?.text = viewModel.title.value
		subscriber = viewModel.title.$value.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] text in
			UIView.setAnimationsEnabled(false)
			self?.tableView?.performBatchUpdates({
				self?.textLabel?.text = text
			})
			UIView.setAnimationsEnabled(true)
		})
	}
}
