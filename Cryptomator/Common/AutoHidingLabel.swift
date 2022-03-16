//
//  AutoHidingLabel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import UIKit

class AutoHidingLabel: UILabel {
	override var text: String? {
		didSet {
			isHidden = text == nil && attributedText == nil
		}
	}

	override var attributedText: NSAttributedString? {
		didSet {
			isHidden = text == nil && attributedText == nil
		}
	}
}
