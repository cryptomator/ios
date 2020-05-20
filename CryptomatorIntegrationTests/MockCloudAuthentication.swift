//
//  MockCloudAuthentication.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 20.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import Promises
protocol MockCloudAuthentication: CloudAuthentication {
	func authenticate() -> Promise<Void>
}
