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
			self?.textLabel?.text = text
			self?.setNeedsLayout()
			guard self?.tableView?.window != nil else {
				return
			}
			UIView.performWithoutAnimation {
				self?.tableView?.performBatchUpdates({
					// performBatchUpdates call is needed to actually trigger an tableView (layout) update
				})
			}
		})
	}
}
