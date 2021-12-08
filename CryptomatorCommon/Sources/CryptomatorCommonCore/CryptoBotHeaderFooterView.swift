//
//  CryptoBotHeaderFooterView.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 08.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

open class CryptoBotHeaderFooterView: LargeHeaderFooterView {
	public init(infoText: String?) {
		super.init(image: UIImage(named: "bot"), infoText: infoText)
	}
}
