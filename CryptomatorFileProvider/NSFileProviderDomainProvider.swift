//
//  NSFileProviderDomainProvider.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

protocol NSFileProviderDomainProvider {
	func getDomains() async throws -> [NSFileProviderDomain]
}

extension NSFileProviderManager: NSFileProviderDomainProvider {
	func getDomains() async throws -> [NSFileProviderDomain] {
		return try await NSFileProviderManager.domains()
	}
}
