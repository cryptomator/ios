//
//  SwitchCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

class SwitchCellViewModel: TableViewCellViewModel {
	var type: TableViewCell.Type {
		SwitchCell.self
	}

	let title: Bindable<String?>
	let titleTextColor: Bindable<UIColor?>
	@Published var isOn: Bool = false
	var isOnButtonPublisher: PassthroughSubject<Bool, Never>

	let detailTitle: Bindable<String?> = Bindable(nil)
	let detailTitleTextColor: Bindable<UIColor?> = Bindable(nil)
	let image: Bindable<UIImage?> = Bindable(nil)
	let isEnabled: Bindable<Bool> = Bindable(true)

	private var subscriber: AnyCancellable?

	init(title: String, titleTextColor: UIColor? = nil, isOn: Bool = false) {
		self.title = Bindable(title)
		self.titleTextColor = Bindable(titleTextColor)
		self.isOn = isOn
		self.isOnButtonPublisher = PassthroughSubject()
	}
}
