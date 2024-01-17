//
//  SystemSymbolButtonCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class SystemSymbolButtonCell: ButtonTableViewCell {
	override func configure(with viewModel: TableViewCellViewModel) {
		super.configure(with: viewModel)
		guard let viewModel = viewModel as? SystemSymbolNameProviding else {
			return
		}
		accessoryView = UIImageView(image: UIImage(systemName: viewModel.symbolName))
	}
}
