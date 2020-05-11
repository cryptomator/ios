//
//  GoogleDriveCloudIdentifierCacheManagerTests.swift
//  CloudAccessPrivateTests
//
//  Created by Philipp Schmid on 11.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
import Foundation
@testable import CloudAccessPrivate

class GoogleDriveCloudIdentifierCacheManagerTests: XCTestCase {

    var cachedCloudIdentifierManager: GoogleDriveCloudIdentifierCacheManager!
    override func setUpWithError() throws {
        guard let manager = GoogleDriveCloudIdentifierCacheManager() else {
            throw TestError.invalidArgumentError("manager is nil")
        }
        cachedCloudIdentifierManager = manager
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCacheAndRetrieveIdentifierForFileURL() throws {
        let identifierToStore = "TestABC--1234@^"
        let remoteURL = URL(fileURLWithPath: "/abc/test.txt")
        try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: remoteURL)
        let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: remoteURL)
        XCTAssertNotNil(retrievedIdentifier)
        XCTAssertEqual(identifierToStore, retrievedIdentifier)
    }
    
    func testCacheAndRetrieveIdentifierForFolderURL() throws {
        let identifierToStore = "TestABC--1234@^"
        let remoteURL = URL(fileURLWithPath: "/abc/test--a-/")
        try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: remoteURL)
        let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: remoteURL)
        XCTAssertNotNil(retrievedIdentifier)
        XCTAssertEqual(identifierToStore, retrievedIdentifier)
    }


}
