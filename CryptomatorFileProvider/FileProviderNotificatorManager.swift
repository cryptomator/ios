//
//  FileProviderNotificatorManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 20.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

protocol FileProviderNotificatorManagerType {
	func getFileProviderNotificator(for domain: NSFileProviderDomain) throws -> FileProviderNotificatorType
}

enum FileProviderNotificatorManagerError: Error {
	case fileProviderManagerInitError
}

public class FileProviderNotificatorManager: FileProviderNotificatorManagerType {
	public static let shared = FileProviderNotificatorManager()
	private let queue = DispatchQueue(label: "FileProviderNotificatorManager")
	private var cache = [NSFileProviderDomainIdentifier: FileProviderNotificatorType]()

	public func getFileProviderNotificator(for domain: NSFileProviderDomain) throws -> FileProviderNotificatorType {
		let domainIdentifier = domain.identifier
		return try queue.sync {
			if let cachedNotificator = cache[domainIdentifier] {
				return cachedNotificator
			}
			guard let manager = NSFileProviderManager(for: domain) else {
				throw FileProviderNotificatorManagerError.fileProviderManagerInitError
			}
			let notificator = FileProviderNotificator(manager: manager)
			cache[domainIdentifier] = notificator
			return notificator
		}
	}
}
