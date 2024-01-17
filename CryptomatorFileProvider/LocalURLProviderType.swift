//
//  LocalURLProviderType.swift
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
	 The identifier for the corresponding domain of the item identifiers.
	 */
	var domainIdentifier: NSFileProviderDomainIdentifier { get }
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

	 - Note: Returns the `.rootContainer` identifier for the special case that the passed `url` corresponds to the `<base storage directory>`. This is necessary to support "Open in Files app".
	 */
	func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
		let pathComponents = url.pathComponents
		assert(pathComponents.count > 2)
		if let itemID = Int64(pathComponents[pathComponents.count - 2]) {
			return NSFileProviderItemIdentifier(domainIdentifier: domainIdentifier, itemID: itemID)
		} else if pathComponents.last == domainIdentifier.rawValue {
			return .rootContainer
		} else {
			return nil
		}
	}
}

public class LocalURLProvider: LocalURLProviderType {
	public var domainIdentifier: NSFileProviderDomainIdentifier {
		domain.identifier
	}

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
		if let itemID = identifier.databaseValue {
			return baseStorageDirectoryURL?.appendingPathComponent(String(itemID), isDirectory: true)
		} else {
			return baseStorageDirectoryURL?.appendingPathComponent(identifier.rawValue, isDirectory: true)
		}
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
