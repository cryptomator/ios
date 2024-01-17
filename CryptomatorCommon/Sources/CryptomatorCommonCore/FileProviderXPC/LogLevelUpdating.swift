//
//  LogLevelUpdating.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 11.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

@objc public protocol LogLevelUpdating: NSFileProviderServiceSource {
	func logLevelUpdated()
}

public extension NSFileProviderServiceName {
	static let logLevelUpdating = NSFileProviderServiceName("org.cryptomator.ios.log-level-updating")
}
