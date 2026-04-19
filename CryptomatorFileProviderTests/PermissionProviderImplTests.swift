//
//  PermissionProviderImplTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 19.09.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

final class PermissionProviderImplTests: XCTestCase {
	private static let defaultFolderCapabilities: NSFileProviderItemCapabilities = [.allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting]
	private var fullVersionCheckerMock: FullVersionCheckerMock!
	private var hubRepositoryMock: HubRepositoryMock!

	override func setUpWithError() throws {
		fullVersionCheckerMock = FullVersionCheckerMock()
		hubRepositoryMock = HubRepositoryMock()
	}

	// MARK: Full Version

	func testUploadingItemRestrictsCapabilityToRead() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = true

			let cloudPath = CloudPath("/test.txt")
			let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual(NSFileProviderItemCapabilities.allowsReading, actualCapabilities)
		}
	}

	func testUploadingFolderDoesNotRestrictCapabilities() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = true

			let cloudPath = CloudPath("/test")
			let metadata = ItemMetadata(id: 2, name: "test", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual(Self.defaultFolderCapabilities, actualCapabilities)
		}
	}

	func testCapabilitiesForRestrictedVersion() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = false

			let cloudPath = CloudPath("/test.txt")
			let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual(NSFileProviderItemCapabilities.allowsReading, actualCapabilities)
		}
	}

	func testFailedUploadItemCapabilitiesForRestrictedVersion() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = false

			let cloudPath = CloudPath("/test.txt")
			let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual(NSFileProviderItemCapabilities.allowsDeleting, actualCapabilities)
		}
	}

	func testFailedUploadFolderCapabilitiesForRestrictedVersion() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = false

			let cloudPath = CloudPath("/test")
			let metadata = ItemMetadata(id: 2, name: "test", type: .folder, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual(NSFileProviderItemCapabilities.allowsDeleting, actualCapabilities)
		}
	}

	func testFullVersionNoActiveHubScriptionReturnsFullPermissionsForFile() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = true
			self.hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .inactive)

			let cloudPath = CloudPath("/test.txt")
			let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual([.allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting], actualCapabilities)
		}
	}

	// MARK: Cryptomator Hub

	func testUploadingItemRestrictsCapabilityToReadWithActiveHubSubscription() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = false
			self.hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .active)

			let cloudPath = CloudPath("/test.txt")
			let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual(NSFileProviderItemCapabilities.allowsReading, actualCapabilities)
		}
	}

	func testNoFullVersionNoActiveHubSubscriptionRestrictsToReadOnly() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = false
			self.hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .inactive)

			let cloudPath = CloudPath("/test.txt")
			let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual(NSFileProviderItemCapabilities.allowsReading, actualCapabilities)
		}
	}

	func testFolderCapabilitiesNoFullVersionActiveHubSubscription() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = false
			self.hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .active)

			let cloudPath = CloudPath("/test.txt")
			let metadata = ItemMetadata(id: 2, name: "test.txt", type: .folder, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual(Self.defaultFolderCapabilities, actualCapabilities)
		}
	}

	func testUploadingFolderDoesNotRestrictCapabilitiesForActiveHubSubsription() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = false
			self.hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .active)

			let cloudPath = CloudPath("/test")
			let metadata = ItemMetadata(id: 2, name: "test", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual(Self.defaultFolderCapabilities, actualCapabilities)
		}
	}

	func testNoFullVersionActiveHubScriptionReturnsFullPermissionsForFile() {
		withDependencies {
			$0.hubRepository = hubRepositoryMock
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			self.fullVersionCheckerMock.isFullVersion = false
			self.hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .active)

			let cloudPath = CloudPath("/test.txt")
			let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
			let actualCapabilities = PermissionProviderImpl().getPermissions(for: metadata, at: .test)
			XCTAssertEqual([.allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting], actualCapabilities)
		}
	}
}
