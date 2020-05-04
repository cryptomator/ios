//
//  GoogleDriveCloudProviderIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 29.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
import CloudAccessPrivate
import CryptomatorCloudAccess
import Promises
class GoogleDriveCloudProviderIntegrationTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /**
        It is necessary to call another function than canAuthorize, because it returns true as soon as any refreshToken is set and does not check it online for correctness before.
     */
    func testAuthenticationWorksWithoutViewController() throws {
        let authentication = MockGoogleDriveCloudAuthentication()
        let refreshToken = "ADD THE REFRESH TOKEN VIA ENV VARIABLE"
        let expectation = XCTestExpectation(description: "Google Authentication works without ViewController")
        authentication.authenticate(withRefreshToken: refreshToken as NSString).then{
            authentication.authorization?.authorizeRequest(nil, completionHandler: { (error) in
                XCTAssertNil(error)
                expectation.fulfill()
            })
        }.catch{ error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchItemList() throws {
        let authentication = MockGoogleDriveCloudAuthentication()
        let refreshToken = "ADD THE REFRESH TOKEN VIA ENV VARIABLE"
        let testURL = URL(fileURLWithPath: "/iOS-IntegrationsTest/smallFolder/", isDirectory: true)
        let expectation = XCTestExpectation(description: "fetchItemList")
        authentication.authenticate(withRefreshToken: refreshToken as NSString).then{ () -> Promise<CloudItemList> in
            let provider = GoogleDriveCloudProvider(with: authentication)
            return provider.fetchItemList(forFolderAt: testURL, withPageToken: nil)
        }.then{ cloudItemList in
            XCTFail("Function not implemented") //MARK: Discuss Integration Test Structure
            
            expectation.fulfill()
        }.catch{ error in
            XCTFail(error.localizedDescription)
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
