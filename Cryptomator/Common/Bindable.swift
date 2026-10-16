//
//  Bindable.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import Foundation

nonisolated class Bindable<Value> {
	@Published var value: Value

	init(_ value: Value) {
		self.value = value
	}
}

nonisolated extension Bindable: Equatable where Value: Equatable {
	static func == (lhs: Bindable<Value>, rhs: Bindable<Value>) -> Bool {
		return lhs.value == rhs.value
	}
}

nonisolated extension Bindable: Hashable where Value: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(value)
	}
}
