//
//  LocalizedString.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 12.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum LocalizedString {
	public static func getValue(_ key: String) -> String {
		let value = NSLocalizedString(key, comment: "")
		if value != key || NSLocale.preferredLanguages.first == "en" {
			return value
		}
		// Fallback to English
		guard let path = Bundle.main.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: path) else {
			return value
		}
		return NSLocalizedString(key, bundle: bundle, comment: "")
	}
}
