//
//  LocalURLProvider.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 03.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import FileProvider
import Foundation

public protocol LocalURLProviderType: AnyObject {
	/**
	 Returns the item identifier directory for a given item identifier.

	 All paths are structured as `<base storage directory>/<item identifier>/`

	 - Note: The path for the `NSFileProviderItemIdentifier.rootContainer` is `<base storage directory>`
	 */
	func itemIdentifierDirectoryURLForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL?
}

public extension LocalURLProviderType {
	/**
	 Resolves the given identifier to a file on disk.

	 All paths are structured as `<base storage directory>/<item identifier>/<item file name>`

	 - Note: The path for the `NSFileProviderItemIdentifier.rootContainer` is `<base storage directory>`
	 */
	func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier, itemName: String) -> URL? {
		let itemIdentifierDirectory = itemIdentifierDirectoryURLForItem(withPersistentIdentifier: identifier)
		if identifier == .rootContainer {
			return itemIdentifierDirectory
		}
		return itemIdentifierDirectory?.appendingPathComponent(itemName, isDirectory: false)
	}

	/**
	 Resolve the given URL to a persistent identifier.

	 This implementation exploits the fact that the path structure has been defined as
	 `<base storage directory>/<item identifier>/<item file name>`.
	 */
	func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
		let pathComponents = url.pathComponents
		assert(pathComponents.count > 2)
		return NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
	}
}

public class LocalURLProvider: LocalURLProviderType {
	private let domain: NSFileProviderDomain
	private let documentStorageURLProvider: DocumentStorageURLProvider

	public init(domain: NSFileProviderDomain, documentStorageURLProvider: DocumentStorageURLProvider = NSFileProviderManager.default) {
		self.domain = domain
		self.documentStorageURLProvider = documentStorageURLProvider
	}

	public func itemIdentifierDirectoryURLForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
		let baseStorageDirectoryURL = getBaseStorageDirectory()
		if identifier == .rootContainer {
			return baseStorageDirectoryURL
		}
		return baseStorageDirectoryURL?.appendingPathComponent(identifier.rawValue, isDirectory: true)
	}

	private func getBaseStorageDirectory() -> URL? {
		let domainDocumentStorage = domain.pathRelativeToDocumentStorage
		do {
			try excludeFileProviderDocumentStorageFromiCloudBackup()
		} catch {
			DDLogError("Exclude FileProviderDocumentStorage from iCloud backup failed with error: \(error)")
			return nil
		}
		return documentStorageURLProvider.documentStorageURL.appendingPathComponent(domainDocumentStorage)
	}

	private func excludeFileProviderDocumentStorageFromiCloudBackup() throws {
		var values = URLResourceValues()
		values.isExcludedFromBackup = true
		var documentStorageURL = documentStorageURLProvider.documentStorageURL
		try documentStorageURL.setResourceValues(values)
	}
}
