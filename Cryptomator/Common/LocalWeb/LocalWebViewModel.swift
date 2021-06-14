//
//  LocalWebViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 14.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

enum LocalWebViewError: Error {
	case resourceNotFound
}

class LocalWebViewModel {
	let title: String

	private let htmlPathName: String

	var baseURL: URL {
		return Bundle.main.bundleURL
	}

	init(title: String, htmlPathName: String) {
		self.title = title
		self.htmlPathName = htmlPathName
	}

	func loadHTMLString() throws -> String {
		guard let htmlURL = Bundle.main.url(forResource: htmlPathName, withExtension: "html") else {
			throw LocalWebViewError.resourceNotFound
		}
		return try String(contentsOf: htmlURL, encoding: .utf8)
	}
}
