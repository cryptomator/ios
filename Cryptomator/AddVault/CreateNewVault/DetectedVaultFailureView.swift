//
//  DetectedVaultFailureView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class DetectedVaultFailureView: DetectedVaultView {
	init(text: String) {
		let configuration = UIImage.SymbolConfiguration(pointSize: 120)
		let warningSymbol = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: configuration)
		let imageView = UIImageView(image: warningSymbol)
		imageView.tintColor = UIColor(named: "yellow")
		super.init(imageView: imageView, text: text)
	}
}
