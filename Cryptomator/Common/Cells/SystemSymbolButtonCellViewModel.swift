//
//  SystemSymbolButtonCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

class SystemSymbolButtonCellViewModel<T>: ButtonCellViewModel<T>, SystemSymbolNameProviding {
	override var type: ConfigurableTableViewCell.Type {
		SystemSymbolButtonCell.self
	}

	let symbolName: String

	init(action: T, title: String, symbolName: String) {
		self.symbolName = symbolName
		super.init(action: action, title: title)
	}
}

protocol SystemSymbolNameProviding {
	var symbolName: String { get }
}
