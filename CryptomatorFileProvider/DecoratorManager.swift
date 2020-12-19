//
//  DecoratorManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 29.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import Promises

public enum DecoratorManager {
	private static var cachedDecorators = [NSFileProviderDomainIdentifier: FileProviderDecorator]()
	private static let queue = DispatchQueue(label: "DecoratorManager")

	public static func getDecorator(for domain: NSFileProviderDomain, with manager: NSFileProviderManager, dbPath: URL) -> Promise<FileProviderDecorator> {
		return Promise<FileProviderDecorator> { fulfill, reject in
			queue.async(flags: .barrier) {
				if let cachedDecorator = cachedDecorators[domain.identifier] {
					fulfill(cachedDecorator)
					return
				}
				let decorator: FileProviderDecorator
				do {
					decorator = try FileProviderDecorator(for: domain, with: manager, dbPath: dbPath)
				} catch {
					reject(error)
					return
				}
				cachedDecorators[domain.identifier] = decorator
				fulfill(decorator)
			}
		}
	}
}
