//
//  DecoratorManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 29.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
public class DecoratorManager {
	private static var cachedDecorators = [NSFileProviderDomainIdentifier: FileProviderDecorator]()
	private static let semaphore = DispatchSemaphore(value: 1)

	public static func getDecorator(for domain: NSFileProviderDomain, with manager: NSFileProviderManager, dbPath: URL) throws -> FileProviderDecorator {
		semaphore.wait()
		if let cachedDecorator = cachedDecorators[domain.identifier] {
			return cachedDecorator
		}
		let decorator = try FileProviderDecorator(for: domain, with: manager, dbPath: dbPath)
		cachedDecorators[domain.identifier] = decorator
		semaphore.signal()
		return decorator
	}
}
