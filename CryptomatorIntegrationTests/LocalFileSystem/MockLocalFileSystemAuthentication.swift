//
//  MockFileSystemAuthentication.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 23.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises
@testable import CryptomatorCloudAccess

class MockLocalFileSystemAuthentication: LocalFileSystemAuthentication, MockCloudAuthentication {
	func authenticate() -> Promise<Void> {
		return Promise(())
	}
}
