//
//  SwitchCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

class SwitchCellViewModel: BindableTableViewCellViewModel {
	override var type: ConfigurableTableViewCell.Type {
		SwitchCell.self
	}

	let isOn: Bindable<Bool>
	var isOnButtonPublisher: PassthroughSubject<Bool, Never>

	private var subscriber: AnyCancellable?

	init(title: String, titleTextColor: UIColor? = nil, isOn: Bool = false) {
		self.isOn = Bindable(isOn)
		self.isOnButtonPublisher = PassthroughSubject()
		super.init(title: title, titleTextColor: titleTextColor, isEnabled: true, selectionStyle: .none)
	}
}
