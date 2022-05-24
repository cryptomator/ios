//
//  LogLevelUpdatingServiceSourceTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 11.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

class LogLevelUpdatingServiceSourceTests: XCTestCase {
	private var cryptomatorSettingsMock: CryptomatorSettingsMock!
	private var serviceSouce: LogLevelUpdatingServiceSource!

	override func setUpWithError() throws {
		cryptomatorSettingsMock = CryptomatorSettingsMock()
		serviceSouce = LogLevelUpdatingServiceSource(cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testLogLevelUpdated() throws {
		cryptomatorSettingsMock.debugModeEnabled = false
		serviceSouce.logLevelUpdated()
		XCTAssertEqual(.error, dynamicLogLevel)

		cryptomatorSettingsMock.debugModeEnabled = true
		serviceSouce.logLevelUpdated()
		XCTAssertEqual(.debug, dynamicLogLevel)
	}
}
