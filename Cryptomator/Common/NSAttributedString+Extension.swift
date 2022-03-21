//
//  NSAttributedString+Extension.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 09.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import UIKit

extension NSAttributedString {
	static func textWithLeadingSystemImage(_ imageName: String, text: String, font: UIFont, color: UIColor) -> NSAttributedString {
		let configuration = UIImage.SymbolConfiguration(font: font)
		let imageAttachment = NSTextAttachment()
		imageAttachment.image = UIImage(systemName: imageName, withConfiguration: configuration)?.withTintColor(color)
		let attributedString = NSMutableAttributedString(attachment: imageAttachment)
		attributedString.append(NSAttributedString(string: " \(text)"))
		attributedString.addAttribute(.foregroundColor,
		                              value: color,
		                              range: NSRange(location: 0, length: attributedString.length))
		attributedString.addAttribute(.font,
		                              value: font,
		                              range: NSRange(location: 0, length: attributedString.length))
		return attributedString
	}
}
