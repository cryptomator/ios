//
//  NSFileProviderDomainProvider.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import Foundation
import Promises

protocol NSFileProviderDomainProvider {
	func getDomains() -> Promise<[NSFileProviderDomain]>
}

extension NSFileProviderManager: NSFileProviderDomainProvider {
	func getDomains() -> Promise<[NSFileProviderDomain]> {
		return NSFileProviderManager.getDomains()
	}
}
