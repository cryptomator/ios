//
//  CacheManagerMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
@testable import CryptomatorFileProvider

// swiftlint:disable all
final class CachedFileManagerMock: CachedFileManager {
	// MARK: - getLocalCachedFileInfo

	var getLocalCachedFileInfoForThrowableError: Error?
	var getLocalCachedFileInfoForCallsCount = 0
	var getLocalCachedFileInfoForCalled: Bool {
		getLocalCachedFileInfoForCallsCount > 0
	}

	var getLocalCachedFileInfoForReceivedId: Int64?
	var getLocalCachedFileInfoForReceivedInvocations: [Int64] = []
	var getLocalCachedFileInfoForReturnValue: LocalCachedFileInfo?
	var getLocalCachedFileInfoForClosure: ((Int64) throws -> LocalCachedFileInfo?)?

	func getLocalCachedFileInfo(for id: Int64) throws -> LocalCachedFileInfo? {
		if let error = getLocalCachedFileInfoForThrowableError {
			throw error
		}
		getLocalCachedFileInfoForCallsCount += 1
		getLocalCachedFileInfoForReceivedId = id
		getLocalCachedFileInfoForReceivedInvocations.append(id)
		return try getLocalCachedFileInfoForClosure.map({ try $0(id) }) ?? getLocalCachedFileInfoForReturnValue
	}

	// MARK: - cacheLocalFileInfo

	var cacheLocalFileInfoForLocalURLLastModifiedDateThrowableError: Error?
	var cacheLocalFileInfoForLocalURLLastModifiedDateCallsCount = 0
	var cacheLocalFileInfoForLocalURLLastModifiedDateCalled: Bool {
		cacheLocalFileInfoForLocalURLLastModifiedDateCallsCount > 0
	}

	var cacheLocalFileInfoForLocalURLLastModifiedDateReceivedArguments: (id: Int64, localURL: URL, lastModifiedDate: Date?)?
	var cacheLocalFileInfoForLocalURLLastModifiedDateReceivedInvocations: [(id: Int64, localURL: URL, lastModifiedDate: Date?)] = []
	var cacheLocalFileInfoForLocalURLLastModifiedDateClosure: ((Int64, URL, Date?) throws -> Void)?

	func cacheLocalFileInfo(for id: Int64, localURL: URL, lastModifiedDate: Date?) throws {
		if let error = cacheLocalFileInfoForLocalURLLastModifiedDateThrowableError {
			throw error
		}
		cacheLocalFileInfoForLocalURLLastModifiedDateCallsCount += 1
		cacheLocalFileInfoForLocalURLLastModifiedDateReceivedArguments = (id: id, localURL: localURL, lastModifiedDate: lastModifiedDate)
		cacheLocalFileInfoForLocalURLLastModifiedDateReceivedInvocations.append((id: id, localURL: localURL, lastModifiedDate: lastModifiedDate))
		try cacheLocalFileInfoForLocalURLLastModifiedDateClosure?(id, localURL, lastModifiedDate)
	}

	// MARK: - removeCachedFile

	var removeCachedFileForThrowableError: Error?
	var removeCachedFileForCallsCount = 0
	var removeCachedFileForCalled: Bool {
		removeCachedFileForCallsCount > 0
	}

	var removeCachedFileForReceivedId: Int64?
	var removeCachedFileForReceivedInvocations: [Int64] = []
	var removeCachedFileForClosure: ((Int64) throws -> Void)?

	func removeCachedFile(for id: Int64) throws {
		if let error = removeCachedFileForThrowableError {
			throw error
		}
		removeCachedFileForCallsCount += 1
		removeCachedFileForReceivedId = id
		removeCachedFileForReceivedInvocations.append(id)
		try removeCachedFileForClosure?(id)
	}

	// MARK: - clearCache

	var clearCacheThrowableError: Error?
	var clearCacheCallsCount = 0
	var clearCacheCalled: Bool {
		clearCacheCallsCount > 0
	}

	var clearCacheClosure: (() throws -> Void)?

	func clearCache() throws {
		if let error = clearCacheThrowableError {
			throw error
		}
		clearCacheCallsCount += 1
		try clearCacheClosure?()
	}

	// MARK: - getLocalCacheSizeInBytes

	var getLocalCacheSizeInBytesThrowableError: Error?
	var getLocalCacheSizeInBytesCallsCount = 0
	var getLocalCacheSizeInBytesCalled: Bool {
		getLocalCacheSizeInBytesCallsCount > 0
	}

	var getLocalCacheSizeInBytesReturnValue: Int!
	var getLocalCacheSizeInBytesClosure: (() throws -> Int)?

	func getLocalCacheSizeInBytes() throws -> Int {
		if let error = getLocalCacheSizeInBytesThrowableError {
			throw error
		}
		getLocalCacheSizeInBytesCallsCount += 1
		return try getLocalCacheSizeInBytesClosure.map({ try $0() }) ?? getLocalCacheSizeInBytesReturnValue
	}
}

// swiftlint:enable all
