//
//  LocalURLProviderMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 03.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import FileProvider
import Foundation

// swiftlint:disable all
/// @unchecked Sendable: test double, never touched concurrently
final class LocalURLProviderMock: LocalURLProviderType, @unchecked Sendable {
	// MARK: - domainIdentifier

	var domainIdentifier: NSFileProviderDomainIdentifier {
		get { underlyingDomainIdentifier }
		set(value) { underlyingDomainIdentifier = value }
	}

	private var underlyingDomainIdentifier: NSFileProviderDomainIdentifier!

	// MARK: - itemIdentifierDirectoryURLForItem

	var itemIdentifierDirectoryURLForItemWithPersistentIdentifierCallsCount = 0
	var itemIdentifierDirectoryURLForItemWithPersistentIdentifierCalled: Bool {
		itemIdentifierDirectoryURLForItemWithPersistentIdentifierCallsCount > 0
	}

	var itemIdentifierDirectoryURLForItemWithPersistentIdentifierReceivedIdentifier: NSFileProviderItemIdentifier?
	var itemIdentifierDirectoryURLForItemWithPersistentIdentifierReceivedInvocations: [NSFileProviderItemIdentifier] = []
	var itemIdentifierDirectoryURLForItemWithPersistentIdentifierReturnValue: URL?
	var itemIdentifierDirectoryURLForItemWithPersistentIdentifierClosure: ((NSFileProviderItemIdentifier) -> URL?)?

	func itemIdentifierDirectoryURLForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
		itemIdentifierDirectoryURLForItemWithPersistentIdentifierCallsCount += 1
		itemIdentifierDirectoryURLForItemWithPersistentIdentifierReceivedIdentifier = identifier
		itemIdentifierDirectoryURLForItemWithPersistentIdentifierReceivedInvocations.append(identifier)
		return itemIdentifierDirectoryURLForItemWithPersistentIdentifierClosure.map({ $0(identifier) }) ?? itemIdentifierDirectoryURLForItemWithPersistentIdentifierReturnValue
	}
}

// swiftlint:enable all
