//
//  NSLayoutConstraint+Extensions.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 01.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import UIKit

// Taken from: https://github.com/carekit-apple/CareKit/blob/main/CareKit/CareKit/iOS/Extensions/NSLayoutConstraint+Extensions.swift

public struct LayoutDirection: OptionSet {
	public let rawValue: Int

	public static let top = LayoutDirection(rawValue: 1 << 0)
	public static let bottom = LayoutDirection(rawValue: 1 << 1)
	public static let leading = LayoutDirection(rawValue: 1 << 2)
	public static let trailing = LayoutDirection(rawValue: 1 << 3)

	public static let horizontal: LayoutDirection = [.leading, .trailing]
	public static let vertical: LayoutDirection = [.top, .bottom]

	public static let all: LayoutDirection = [.horizontal, .vertical]

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}
}

extension NSLayoutConstraint {
	func withPriority(_ new: UILayoutPriority) -> NSLayoutConstraint {
		priority = new
		return self
	}
}

public extension UIView {
	func constraints(equalTo other: UIView, directions: LayoutDirection = .all,
	                 priority: UILayoutPriority = .required) -> [NSLayoutConstraint] {
		var constraints: [NSLayoutConstraint] = []
		if directions.contains(.top) {
			constraints.append(topAnchor.constraint(equalTo: other.topAnchor).withPriority(priority))
		}
		if directions.contains(.leading) {
			constraints.append(leadingAnchor.constraint(equalTo: other.leadingAnchor).withPriority(priority))
		}
		if directions.contains(.bottom) {
			constraints.append(bottomAnchor.constraint(equalTo: other.bottomAnchor).withPriority(priority))
		}
		if directions.contains(.trailing) {
			constraints.append(trailingAnchor.constraint(equalTo: other.trailingAnchor).withPriority(priority))
		}
		return constraints
	}

	func constraints(equalTo layoutGuide: UILayoutGuide, directions: LayoutDirection = .all,
	                 priority: UILayoutPriority = .required) -> [NSLayoutConstraint] {
		var constraints: [NSLayoutConstraint] = []
		if directions.contains(.top) {
			constraints.append(topAnchor.constraint(equalTo: layoutGuide.topAnchor).withPriority(priority))
		}
		if directions.contains(.leading) {
			constraints.append(leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor).withPriority(priority))
		}
		if directions.contains(.bottom) {
			constraints.append(bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor).withPriority(priority))
		}
		if directions.contains(.trailing) {
			constraints.append(trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor).withPriority(priority))
		}
		return constraints
	}
}

public extension UILayoutPriority {
	static var almostRequired: UILayoutPriority {
		return .required - 1
	}
}
