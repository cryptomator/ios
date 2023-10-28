//
//  CacheManagingServiceSourceTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider
@testable import Dependencies

class CacheManagingServiceSourceTests: XCTestCase {
	var serviceSource: CacheManagingServiceSource!
	var cacheManagerFactoryMock: CachedFileManagerFactoryMock!
	var domainProviderMock: NSFileProviderDomainProviderMock!
	var notificatorMock: FileProviderNotificatorTypeMock!
	let domains = [NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("1")),
	               NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("2"))]

	override func setUpWithError() throws {
		cacheManagerFactoryMock = CachedFileManagerFactoryMock()
		domainProviderMock = NSFileProviderDomainProviderMock()
		notificatorMock = FileProviderNotificatorTypeMock()
		serviceSource = CacheManagingServiceSource(notificator: notificatorMock, cachedManagerFactory: cacheManagerFactoryMock, domainProvider: domainProviderMock)
	}

	func testClearCache() {
		let expectation = XCTestExpectation()
		let cacheManagerMocks = [CachedFileManagerMock(),
		                         CachedFileManagerMock()]
		domainProviderMock.getDomainsReturnValue = Promise(domains)
		cacheManagerFactoryMock.createCachedFileManagerForClosure = { domain in
			guard let index = self.domains.firstIndex(of: domain) else {
				throw NSError(domain: "TestError", code: -100, userInfo: nil)
			}
			return cacheManagerMocks[index]
		}

		serviceSource.clearCache { error in
			XCTAssertNil(error)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)

		XCTAssertEqual(1, domainProviderMock.getDomainsCallsCount)
		// Assert created a CachedFileManager for every domain
		XCTAssertEqual(domains, cacheManagerFactoryMock.createCachedFileManagerForReceivedInvocations)
		// Assert cleared cache for every domain
		XCTAssertEqual(1, cacheManagerMocks[0].clearCacheCallsCount)
		XCTAssertEqual(1, cacheManagerMocks[1].clearCacheCallsCount)
	}

	func testEvictFileFromCache() {
		let expectation = XCTestExpectation()
		let cacheManagerMock = CachedFileManagerMock()
		cacheManagerFactoryMock.createCachedFileManagerForReturnValue = cacheManagerMock
		let permissionProviderMock = PermissionProviderMock()
		DependencyValues.mockDependency(\.permissionProvider, with: permissionProviderMock)
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading
		let domainIdentifier = NSFileProviderDomainIdentifier("Test-Domain")
		let itemID: Int64 = 2
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: domainIdentifier, itemID: itemID)
		let testItem = FileProviderItem(metadata: ItemMetadata(id: itemID, name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false), domainIdentifier: .test)
		serviceSource.getItem = { receivedItemIdentifier in
			guard itemIdentifier == receivedItemIdentifier else {
				return nil
			}
			return testItem
		}
		serviceSource.evictFileFromCache(with: itemIdentifier) { error in
			XCTAssertNil(error)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)

		XCTAssertEqual([itemID], cacheManagerMock.removeCachedFileForReceivedInvocations)
		XCTAssertEqual([domainIdentifier], cacheManagerFactoryMock.createCachedFileManagerForReceivedInvocations.map { $0.identifier })
		// Assert signaled an update for the evicted item
		XCTAssertEqual([testItem], notificatorMock.signalUpdateForReceivedInvocations as? [FileProviderItem])
	}

	func testGetLocalCacheSizeInBytes() {
		let expectation = XCTestExpectation()
		let expectedCacheSize: NSNumber = 42

		let firstCacheManagerMock = CachedFileManagerMock()
		firstCacheManagerMock.getLocalCacheSizeInBytesReturnValue = 20

		let secondCacheManagerMock = CachedFileManagerMock()
		secondCacheManagerMock.getLocalCacheSizeInBytesReturnValue = 22

		let cacheManagerMocks = [firstCacheManagerMock,
		                         secondCacheManagerMock]
		domainProviderMock.getDomainsReturnValue = Promise(domains)
		cacheManagerFactoryMock.createCachedFileManagerForClosure = { domain in
			guard let index = self.domains.firstIndex(of: domain) else {
				throw NSError(domain: "TestError", code: -100, userInfo: nil)
			}
			return cacheManagerMocks[index]
		}

		serviceSource.getLocalCacheSizeInBytes { actualCacheSize, error in
			XCTAssertNil(error)
			XCTAssertEqual(expectedCacheSize, actualCacheSize)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)

		XCTAssertEqual(1, domainProviderMock.getDomainsCallsCount)
		// Assert created a CachedFileManager for every domain
		XCTAssertEqual(domains, cacheManagerFactoryMock.createCachedFileManagerForReceivedInvocations)

		// Assert called `getLocalCacheSizeInBytes()` for every domain
		XCTAssertEqual(1, firstCacheManagerMock.getLocalCacheSizeInBytesCallsCount)
		XCTAssertEqual(1, secondCacheManagerMock.getLocalCacheSizeInBytesCallsCount)
		XCTAssertFalse(notificatorMock.signalUpdateForCalled)
	}
}
