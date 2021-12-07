//
//  LoadingButtonCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

class LoadingButtonCellViewModel<T>: ButtonCellViewModel<T>, LoadingIndicatorSupport {
	override var type: ConfigurableTableViewCell.Type { LoadingButtonCell.self }
	let isLoading: Bindable<Bool>

	init(action: T, title: String, isLoading: Bool = false) {
		self.isLoading = Bindable(isLoading)
		super.init(action: action, title: title)
	}
}

protocol LoadingIndicatorSupport {
	var isLoading: Bindable<Bool> { get }
}
