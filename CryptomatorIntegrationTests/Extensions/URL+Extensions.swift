//
//  URL+Extensions.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 25.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
extension URL {
	/**
	 Append Path Components from an URL to a copy of the current URL.
	 e.g.: currentURL = "/AAA/"
	 otherURL = "/BBB/example.txt"
	 resultingURL = /AAA/BBB/example.txt

	 - Precondition: startIndex > 0 (default: startIndex = 1)
	 - Precondition: the url from which the function is called has a directoryPath
	 */
	func appendPathComponents(from other: URL, startIndex: Int = 1) -> URL {
		precondition(startIndex > 0)
		precondition(hasDirectoryPath)
		var result = self
		let components = other.pathComponents
		for i in startIndex ..< components.count {
			let isDirectory = (i < components.count - 1 || other.hasDirectoryPath)
			result.appendPathComponent(components[i], isDirectory: isDirectory)
		}
		return result
	}

	/**
	 Get all partialURLs from the current URL.
	 e.g.: currentURL = "/AAA/BBB/CCC/example.txt"
	 returns the following URLs:
	 "/AAA/", "/AAA/BBB/", "/AAA/BBB/CCC/"

	 - Precondition: startIndex > 1 (default: startIndex = 2)
	 */
	func getPartialURLs(startIndex: Int = 2) -> [URL] {
		precondition(startIndex > 1)
		var subURLs = [URL]()
		var url = self
		while url.pathComponents.count > startIndex {
			url = url.deletingLastPathComponent()
			print("URL: \(url) count: \(url.pathComponents.count)")
			subURLs.append(url)
		}
		subURLs.reverse()
		return subURLs
	}
}
