//
//  PermissionProviderImplTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 19.09.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider
@testable import Dependencies

final class PermissionProviderImplTests: XCTestCase {
	private static let defaultFolderCapabilities: NSFileProviderItemCapabilities = [.allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting]
	private var fullVersionCheckerMock: FullVersionCheckerMock!
	private var hubRepositoryMock: HubRepositoryMock!
	private var permissionProvider: PermissionProviderImpl!

	override func setUpWithError() throws {
		fullVersionCheckerMock = FullVersionCheckerMock()
		hubRepositoryMock = HubRepositoryMock()
		DependencyValues.mockDependency(\.hubRepository, with: hubRepositoryMock)
		DependencyValues.mockDependency(\.fullVersionChecker, with: fullVersionCheckerMock)
		permissionProvider = PermissionProviderImpl()
	}

	// MARK: Full Version

	func testUploadingItemRestrictsCapabilityToRead() {
		fullVersionCheckerMock.isFullVersion = true

		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual(NSFileProviderItemCapabilities.allowsReading, actualCapabilities)
	}

	func testUploadingFolderDoesNotRestrictCapabilities() {
		fullVersionCheckerMock.isFullVersion = true

		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual(Self.defaultFolderCapabilities, actualCapabilities)
	}

	func testCapabilitiesForRestrictedVersion() {
		fullVersionCheckerMock.isFullVersion = false

		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual(NSFileProviderItemCapabilities.allowsReading, actualCapabilities)
	}

	func testFailedUploadItemCapabilitiesForRestrictedVersion() {
		fullVersionCheckerMock.isFullVersion = false

		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual(NSFileProviderItemCapabilities.allowsDeleting, actualCapabilities)
	}

	func testFailedUploadFolderCapabilitiesForRestrictedVersion() {
		fullVersionCheckerMock.isFullVersion = false

		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .folder, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual(NSFileProviderItemCapabilities.allowsDeleting, actualCapabilities)
	}

	func testFullVersionNoActiveHubScriptionReturnsFullPermissionsForFile() {
		fullVersionCheckerMock.isFullVersion = true
		hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .inactive)

		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual([.allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting], actualCapabilities)
	}

	// MARK: Cryptomator Hub

	func testUploadingItemRestrictsCapabilityToReadWithActiveHubSubscription() {
		fullVersionCheckerMock.isFullVersion = false
		hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .active)

		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual(NSFileProviderItemCapabilities.allowsReading, actualCapabilities)
	}

	func testNoFullVersionNoActiveHubSubscriptionRestrictsToReadOnly() {
		fullVersionCheckerMock.isFullVersion = false
		hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .inactive)

		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual(NSFileProviderItemCapabilities.allowsReading, actualCapabilities)
	}

	func testFolderCapabilitiesNoFullVersionActiveHubSubscription() {
		fullVersionCheckerMock.isFullVersion = false
		hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .active)

		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .folder, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual(Self.defaultFolderCapabilities, actualCapabilities)
	}

	func testUploadingFolderDoesNotRestrictCapabilitiesForActiveHubSubsription() {
		fullVersionCheckerMock.isFullVersion = false
		hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .active)

		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual(Self.defaultFolderCapabilities, actualCapabilities)
	}

	func testNoFullVersionActiveHubScriptionReturnsFullPermissionsForFile() {
		fullVersionCheckerMock.isFullVersion = false
		hubRepositoryMock.getHubVaultVaultIDReturnValue = .init(vaultUID: "12345", subscriptionState: .active)

		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let actualCapabilities = permissionProvider.getPermissions(for: metadata, at: .test)
		XCTAssertEqual([.allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting], actualCapabilities)
	}
}
