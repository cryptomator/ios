//
//  TableViewCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
protocol TableViewCellViewModel: AnyObject {
	var type: TableViewCell.Type { get }
	var title: Bindable<String?> { get }
	var titleTextColor: Bindable<UIColor?> { get }
	var detailTitle: Bindable<String?> { get }
	var detailTitleTextColor: Bindable<UIColor?> { get }
	var image: Bindable<UIImage?> { get }
	var isEnabled: Bindable<Bool> { get }
}

class DefaultTableCellViewModel: TableViewCellViewModel {
	var type: TableViewCell.Type {
		return TableViewCell.self
	}

	var title: Bindable<String?>
	var titleTextColor: Bindable<UIColor?>
	var detailTitle: Bindable<String?>
	var detailTitleTextColor: Bindable<UIColor?>
	var image: Bindable<UIImage?>
	var isEnabled: Bindable<Bool>

	init(title: String? = nil, titleTextColor: UIColor? = nil, detailTitle: String? = nil, detailTitleTextColor: UIColor? = nil, image: UIImage? = nil, isEnabled: Bool = true) {
		self.title = Bindable(title)
		self.titleTextColor = Bindable(titleTextColor)
		self.detailTitle = Bindable(detailTitle)
		self.detailTitleTextColor = Bindable(detailTitleTextColor)
		self.image = Bindable(image)
		self.isEnabled = Bindable(isEnabled)
	}
}
