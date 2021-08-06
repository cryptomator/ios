//
//  Bindable.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import Foundation
class Bindable<Value> {
	@Published var value: Value

	init(_ value: Value) {
		self.value = value
	}
}
