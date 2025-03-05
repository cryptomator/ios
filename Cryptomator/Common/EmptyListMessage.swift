//
//  EmptyListMessage.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 15.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class EmptyListMessage: UIView {
	convenience init(message: String) {
		self.init(frame: CGRect.zero)
		let arrow = CurvedArrow(lineWidth: 1)
		arrow.translatesAutoresizingMaskIntoConstraints = false
		addSubview(arrow)

		let messageLabel = UILabel()
		messageLabel.font = .preferredFont(forTextStyle: .body)
		messageLabel.numberOfLines = 0
		messageLabel.adjustsFontForContentSizeCategory = true
		messageLabel.text = message
		messageLabel.translatesAutoresizingMaskIntoConstraints = false
		messageLabel.textAlignment = .center
		addSubview(messageLabel)

		NSLayoutConstraint.activate([
			messageLabel.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor),
			messageLabel.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
			messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
		])

		NSLayoutConstraint.activate([
			arrow.leadingAnchor.constraint(equalTo: messageLabel.centerXAnchor),
			arrow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
			arrow.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
			arrow.bottomAnchor.constraint(equalTo: messageLabel.topAnchor, constant: -10)
		])
	}

	class CurvedArrow: UIView {
		convenience init(lineWidth: CGFloat) {
			self.init(frame: CGRect.zero)
			shapeLayer.path = arrowPath().cgPath
			shapeLayer.fillColor = nil
			shapeLayer.lineWidth = lineWidth
		}

		private func arrowPath() -> UIBezierPath {
			let path = UIBezierPath()
			path.move(to: .init(
				x: layer.bounds.minX,
				y: layer.bounds.maxY
			))

			path.addQuadCurve(to: .init(
				x: layer.bounds.maxX,
				y: layer.bounds.minY
			),
			controlPoint: .init(
				x: layer.bounds.maxX,
				y: layer.bounds.maxY / 2
			))
			return path
		}

		override static var layerClass: AnyClass {
			return CAShapeLayer.self
		}

		private var shapeLayer: CAShapeLayer {
			// swiftlint:disable:next force_cast
			return layer as! CAShapeLayer
		}

		override func layoutSubviews() {
			super.layoutSubviews()
			shapeLayer.strokeColor = UIColor.label.cgColor
			shapeLayer.path = arrowPath().cgPath
		}
	}
}

#if DEBUG
import SwiftUI

struct EmptyListMessagePreview: PreviewProvider {
	static var previews: some View {
		EmptyListMessage(message: "Tap here to add a vault").toPreview()
	}
}
#endif
