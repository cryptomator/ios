//
//  LoadingWithLabelCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 05.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class LoadingWithLabelCellViewModel: BindableTableViewCellViewModel {
	override var type: ConfigurableTableViewCell.Type {
		LoadingWithLabelCell.self
	}

	let isLoading: Bindable<Bool>

	init(title: String, isLoading: Bool = false) {
		self.isLoading = Bindable(isLoading)
		super.init(title: title)
	}
}
