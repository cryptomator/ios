//
//  AboutViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 14.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

class AboutViewModel: LocalWebViewModel {
	init() {
		// swiftlint:disable:next force_cast
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
		// swiftlint:disable:next force_cast
		let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
		let title = String(format: NSLocalizedString("settings.aboutCryptomator.title", comment: ""), version, build)
		super.init(title: title, htmlPathName: "about")
	}
}
