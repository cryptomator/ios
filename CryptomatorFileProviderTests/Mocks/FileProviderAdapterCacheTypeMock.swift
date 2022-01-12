//
//  FileProviderAdapterCacheTypeMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
@testable import CryptomatorFileProvider

final class FileProviderAdapterCacheTypeMock: FileProviderAdapterCacheType {
	// MARK: - cacheItem

	var cacheItemIdentifierCallsCount = 0
	var cacheItemIdentifierCalled: Bool {
		cacheItemIdentifierCallsCount > 0
	}

	var cacheItemIdentifierReceivedArguments: (item: AdapterCacheItem, identifier: NSFileProviderDomainIdentifier)?
	var cacheItemIdentifierReceivedInvocations: [(item: AdapterCacheItem, identifier: NSFileProviderDomainIdentifier)] = []
	var cacheItemIdentifierClosure: ((AdapterCacheItem, NSFileProviderDomainIdentifier) -> Void)?

	func cacheItem(_ item: AdapterCacheItem, identifier: NSFileProviderDomainIdentifier) {
		cacheItemIdentifierCallsCount += 1
		cacheItemIdentifierReceivedArguments = (item: item, identifier: identifier)
		cacheItemIdentifierReceivedInvocations.append((item: item, identifier: identifier))
		cacheItemIdentifierClosure?(item, identifier)
	}

	// MARK: - removeItem

	var removeItemIdentifierCallsCount = 0
	var removeItemIdentifierCalled: Bool {
		removeItemIdentifierCallsCount > 0
	}

	var removeItemIdentifierReceivedIdentifier: NSFileProviderDomainIdentifier?
	var removeItemIdentifierReceivedInvocations: [NSFileProviderDomainIdentifier] = []
	var removeItemIdentifierClosure: ((NSFileProviderDomainIdentifier) -> Void)?

	func removeItem(identifier: NSFileProviderDomainIdentifier) {
		removeItemIdentifierCallsCount += 1
		removeItemIdentifierReceivedIdentifier = identifier
		removeItemIdentifierReceivedInvocations.append(identifier)
		removeItemIdentifierClosure?(identifier)
	}

	// MARK: - getItem

	var getItemIdentifierCallsCount = 0
	var getItemIdentifierCalled: Bool {
		getItemIdentifierCallsCount > 0
	}

	var getItemIdentifierReceivedIdentifier: NSFileProviderDomainIdentifier?
	var getItemIdentifierReceivedInvocations: [NSFileProviderDomainIdentifier] = []
	var getItemIdentifierReturnValue: AdapterCacheItem?
	var getItemIdentifierClosure: ((NSFileProviderDomainIdentifier) -> AdapterCacheItem?)?

	func getItem(identifier: NSFileProviderDomainIdentifier) -> AdapterCacheItem? {
		getItemIdentifierCallsCount += 1
		getItemIdentifierReceivedIdentifier = identifier
		getItemIdentifierReceivedInvocations.append(identifier)
		return getItemIdentifierClosure.map({ $0(identifier) }) ?? getItemIdentifierReturnValue
	}

	// MARK: - getAllCachedIdentifiers

	var getAllCachedIdentifiersCallsCount = 0
	var getAllCachedIdentifiersCalled: Bool {
		getAllCachedIdentifiersCallsCount > 0
	}

	var getAllCachedIdentifiersReturnValue: [NSFileProviderDomainIdentifier]!
	var getAllCachedIdentifiersClosure: (() -> [NSFileProviderDomainIdentifier])?

	func getAllCachedIdentifiers() -> [NSFileProviderDomainIdentifier] {
		getAllCachedIdentifiersCallsCount += 1
		return getAllCachedIdentifiersClosure.map({ $0() }) ?? getAllCachedIdentifiersReturnValue
	}
}
