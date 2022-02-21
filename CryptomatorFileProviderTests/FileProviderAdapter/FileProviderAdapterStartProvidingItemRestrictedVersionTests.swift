//
//  FileProviderAdapterStartProvidingItemRestrictedVersionTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 02.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

// swiftlint:disable:next type_name
class FileProviderAdapterStartProvidingItemRestrictedVersionTests: FileProviderAdapterStartProvidingItemTests {
	override func setUpWithError() throws {
		try super.setUpWithError()
		fullVersionCheckerMock.isFullVersion = false
	}

	override func assertNewestVersionDownloaded(localURL: URL, cloudPath: CloudPath, itemID: Int64) {
		super.assertNewestVersionDownloaded(localURL: localURL, cloudPath: cloudPath, itemID: itemID)
		let attributes: [FileAttributeKey: Any]
		do {
			attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
		} catch {
			XCTFail("attributesOfItem at path: \(localURL.path) failed with error: \(error)")
			return
		}
		guard let immutable = attributes[.immutable] as? Bool else {
			XCTFail("Missing FileAttributeKey .immutable")
			return
		}
		XCTAssertTrue(immutable)
		// Remove the immutable flag so the file can be deleted in the tear down
		try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: localURL.path)
	}
}
