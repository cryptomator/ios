//
//  NSLayoutConstraint+Extensions.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 01.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import UIKit

public extension UILayoutPriority {
	static var almostRequired: UILayoutPriority {
		return .required - 1
	}
}
