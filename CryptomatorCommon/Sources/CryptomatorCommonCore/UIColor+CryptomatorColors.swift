//
//  UIColor+CryptomatorColors.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 28.02.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import SwiftUI
import UIKit

public extension UIColor {
	static var cryptomatorPrimary: UIColor {
		return UIColor(named: "primary")!
	}

	static var cryptomatorBackground: UIColor {
		return UIColor(named: "background")!
	}

	static var cryptomatorYellow: UIColor {
		return UIColor(named: "yellow")!
	}
}

public extension Color {
	static var cryptomatorPrimary: Color { Color(UIColor.cryptomatorPrimary) }
	static var cryptomatorBackground: Color { Color(UIColor.cryptomatorBackground) }
	static var cryptomatorYellow: Color { Color(UIColor.cryptomatorYellow) }
}
