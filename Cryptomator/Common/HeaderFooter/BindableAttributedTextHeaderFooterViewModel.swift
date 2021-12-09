//
//  BindableAttributedTextHeaderFooterViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 05.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

class BindableAttributedTextHeaderFooterViewModel: HeaderFooterViewModel {
	var viewType: HeaderFooterViewModelConfiguring.Type { return BindableAttributedTextHeaderFooterView.self }
	var title: Bindable<String?> { return Bindable(nil) }
	let attributedText: Bindable<NSAttributedString>

	init(attributedText: NSAttributedString) {
		self.attributedText = Bindable(attributedText)
	}
}
