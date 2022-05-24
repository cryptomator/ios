//
//  CacheManagingMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 11.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import FileProvider
import Foundation

// swiftlint:disable all

final class CacheManagingMock: CacheManaging, NSFileProviderServiceSource {
	let serviceName: NSFileProviderServiceName = .cacheManaging

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		throw NSError(domain: "MockError", code: -100)
	}

	// MARK: - evictFileFromCache

	var evictFileFromCacheWithReplyCallsCount = 0
	var evictFileFromCacheWithReplyCalled: Bool {
		evictFileFromCacheWithReplyCallsCount > 0
	}

	var evictFileFromCacheWithReplyReceivedArguments: (identifier: NSFileProviderItemIdentifier, reply: (NSError?) -> Void)?
	var evictFileFromCacheWithReplyReceivedInvocations: [(identifier: NSFileProviderItemIdentifier, reply: (NSError?) -> Void)] = []
	var evictFileFromCacheWithReplyClosure: ((NSFileProviderItemIdentifier, @escaping (NSError?) -> Void) -> Void)?

	func evictFileFromCache(with identifier: NSFileProviderItemIdentifier, reply: @escaping (NSError?) -> Void) {
		evictFileFromCacheWithReplyCallsCount += 1
		evictFileFromCacheWithReplyReceivedArguments = (identifier: identifier, reply: reply)
		evictFileFromCacheWithReplyReceivedInvocations.append((identifier: identifier, reply: reply))
		evictFileFromCacheWithReplyClosure?(identifier, reply)
	}

	// MARK: - clearCache

	var clearCacheReplyCallsCount = 0
	var clearCacheReplyCalled: Bool {
		clearCacheReplyCallsCount > 0
	}

	var clearCacheReplyReceivedReply: ((NSError?) -> Void)?
	var clearCacheReplyReceivedInvocations: [(NSError?) -> Void] = []
	var clearCacheReplyClosure: ((@escaping (NSError?) -> Void) -> Void)?

	func clearCache(reply: @escaping (NSError?) -> Void) {
		clearCacheReplyCallsCount += 1
		clearCacheReplyReceivedReply = reply
		clearCacheReplyReceivedInvocations.append(reply)
		clearCacheReplyClosure?(reply)
	}

	// MARK: - getLocalCacheSizeInBytes

	var getLocalCacheSizeInBytesReplyCallsCount = 0
	var getLocalCacheSizeInBytesReplyCalled: Bool {
		getLocalCacheSizeInBytesReplyCallsCount > 0
	}

	var getLocalCacheSizeInBytesReplyReceivedReply: ((NSNumber?, NSError?) -> Void)?
	var getLocalCacheSizeInBytesReplyReceivedInvocations: [(NSNumber?, NSError?) -> Void] = []
	var getLocalCacheSizeInBytesReplyClosure: ((@escaping (NSNumber?, NSError?) -> Void) -> Void)?

	func getLocalCacheSizeInBytes(reply: @escaping (NSNumber?, NSError?) -> Void) {
		getLocalCacheSizeInBytesReplyCallsCount += 1
		getLocalCacheSizeInBytesReplyReceivedReply = reply
		getLocalCacheSizeInBytesReplyReceivedInvocations.append(reply)
		getLocalCacheSizeInBytesReplyClosure?(reply)
	}
}

// swiftlint:enable all
#endif
