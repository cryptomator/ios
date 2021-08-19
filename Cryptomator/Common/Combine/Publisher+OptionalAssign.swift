//
//  Publisher+OptionalAssign.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import Foundation

extension Publisher where Failure == Never {
	func assign<Root: AnyObject>(to keyPath: ReferenceWritableKeyPath<Root, Output>, on root: Root?) -> AnyCancellable {
		sink { [weak root] in
			root?[keyPath: keyPath] = $0
		}
	}
}
