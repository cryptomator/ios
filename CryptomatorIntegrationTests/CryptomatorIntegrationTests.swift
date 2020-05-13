//
//  CryptomatorIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 29.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
import CryptomatorCloudAccess
import CloudAccessPrivate

class CryptomatorIntegrationTests: XCTestCase {

    var provider: CloudProvider!
    var authentication: CloudAuthentication!
    let providerToTest: SupportedCloudProviderForIntegrationTests
    
    init(with providerToTest: SupportedCloudProviderForIntegrationTests) {
        self.providerToTest = providerToTest
    }
    
    override func setUpWithError() throws {
        switch providerToTest {
        case .GoogleDrive:
            authentication = MockGoogleDriveCloudAuthentication()
            provider = GoogleDriveCloudProvider(with: authentication)
        default:
            throw IntegrationTestError.providerNotSupported
        }
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
