//
//  SwiftUI+Focus.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation

public extension CaseIterable where Self: Equatable {
	func next() -> Self? {
		let all = Self.allCases
		let idx = all.firstIndex(of: self)!
		let next = all.index(after: idx)
		guard next < all.endIndex else {
			return nil
		}
		return all[next]
	}
}
