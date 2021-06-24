//
//  LocalFileSystemAuthenticationViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
protocol LocalFileSystemAuthenticationViewModelProtocol {
	var documentPickerButtonText: String { get }
	var headerText: String { get }
	func userPicked(urls: [URL]) throws -> LocalFileSystemCredential
}

class LocalFileSystemAuthenticationViewModel: LocalFileSystemAuthenticationViewModelProtocol {
	let documentPickerButtonText: String
	let headerText: String

	init(documentPickerButtonText: String, headerText: String) {
		self.documentPickerButtonText = documentPickerButtonText
		self.headerText = headerText
	}

	func userPicked(urls: [URL]) throws -> LocalFileSystemCredential {
		guard let rootURL = urls.first else {
			throw LocalFileSystemAuthenticationViewModelError.invalidURL
		}
		let credential = LocalFileSystemCredential(rootURL: rootURL, identifier: UUID().uuidString)
		try LocalFileSystemBookmarkManager.saveBookmarkForRootURL(credential.rootURL, for: credential.identifier)
		return credential
	}
}

struct LocalFileSystemCredential {
	let rootURL: URL
	let identifier: String
}

enum LocalFileSystemAuthenticationViewModelError: Error {
	case invalidURL
}
