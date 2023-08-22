//
//  DatabaseURLProvider.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

public struct DatabaseURLProvider {
	public static let shared = DatabaseURLProvider(documentStorageURLProvider: NSFileProviderManager.default)
	let documentStorageURLProvider: DocumentStorageURLProvider

	public func getDatabaseURL(for domain: NSFileProviderDomain) -> URL {
		let documentStorageURL = documentStorageURLProvider.documentStorageURL
		let domainURL = documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage, isDirectory: true)
		return domainURL.appendingPathComponent("db.sqlite", isDirectory: false)
	}
}
