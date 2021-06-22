//
//  UIView+Shaking.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 14.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CoreGraphics
import Foundation
import UIKit

public extension UIView {
	static let shakeAnimationKey = "UIView.shake"

	func shake() {
		let animation = CAKeyframeAnimation(keyPath: "position")
		animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
		animation.path = shakeAnimationPath(from: layer.position)
		animation.duration = 0.8
		layer.add(animation, forKey: UIView.shakeAnimationKey)
	}

	private func shakeAnimationPath(from position: CGPoint) -> CGPath {
		let path = CGMutablePath()
		path.move(to: position)
		path.addLine(to: CGPoint(x: position.x - 22.0, y: position.y))
		path.addLine(to: CGPoint(x: position.x + 18.0, y: position.y))
		path.addLine(to: CGPoint(x: position.x - 14.0, y: position.y))
		path.addLine(to: CGPoint(x: position.x + 10.0, y: position.y))
		path.addLine(to: CGPoint(x: position.x - 6.0, y: position.y))
		path.addLine(to: CGPoint(x: position.x + 2.0, y: position.y))
		path.addLine(to: position)
		path.closeSubpath()
		return path
	}

	func cancelShaking() {
		layer.removeAnimation(forKey: UIView.shakeAnimationKey)
	}
}
