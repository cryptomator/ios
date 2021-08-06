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
	var subscriber: AnyCancellable?

	func configure(with viewModel: HeaderFooterViewModel) {
		textLabel?.numberOfLines = 0
		subscriber = viewModel.title.$value.assign(to: \.text, on: textLabel)
	}
}
