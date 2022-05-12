//
//  NSFileProviderItemIdentifier+Database.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 04.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

public extension NSFileProviderItemIdentifier {
	static let rootContainerDatabaseValue: Int64 = 1
	private static let delimiter: Character = ":"

	/**
	 Preferred constructor to create an `NSFileProviderItemIdentifier`.

	 An `NSFileProviderItemIdentifier` has the format:
	 `<domainIdentifier>:<itemID>`

	 This ensures that the `NSFileProviderDomainIdentifier` can be derived from any `NSFileProviderItemIdentifier` (except the `.rootContainer` and `.workingSet`).
	 This is necessary because the `extensionContext.domainIdentifier` in the FileProviderExtensionUI is not guaranteed to be the `domainIdentifier`
	 of the currently visible `NSFileProviderDomain` and thus a correct XPC connection could not be established.
	 */
	init(domainIdentifier: NSFileProviderDomainIdentifier, itemID: Int64) {
		if itemID == NSFileProviderItemIdentifier.rootContainerDatabaseValue {
			self.init(rawValue: NSFileProviderItemIdentifier.rootContainer.rawValue)
		} else {
			self.init(rawValue: "\(domainIdentifier.rawValue)\(NSFileProviderItemIdentifier.delimiter)\(itemID)")
		}
	}

	/**
	 The identifier of the domain to which the item with this `NSFileProviderItemIdentifier` belongs.

	 To use this attribute the `NSFileProviderItemIdentifier` must have been created with the constructor `init(domainIdentifier:itemID:)`.
	 This attribute is always nil for `.rootContainer` and `.workingSet`.
	 */
	var domainIdentifier: NSFileProviderDomainIdentifier? {
		guard let index = rawValue.firstIndex(of: NSFileProviderItemIdentifier.delimiter) else {
			return nil
		}
		let before = rawValue.prefix(upTo: index)
		return NSFileProviderDomainIdentifier(String(before))
	}

	/**
	 Representation of the identifier as it is stored in the database.

	 The database value corresponds to the `itemID` which was passed to the constructor `init(domainIdentifier:itemID:)` and `1` for the `.rootContainer`.
	 */
	var databaseValue: Int64? {
		if self == .rootContainer {
			return NSFileProviderItemIdentifier.rootContainerDatabaseValue
		}
		guard let index = rawValue.firstIndex(of: NSFileProviderItemIdentifier.delimiter) else {
			return nil
		}
		let after = rawValue.suffix(from: index).dropFirst()
		return Int64(after)
	}
}
