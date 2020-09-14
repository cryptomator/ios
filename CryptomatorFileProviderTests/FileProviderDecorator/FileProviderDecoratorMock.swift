//
//  FileProviderDecoratorMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 15.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import FileProvider
import Foundation
@testable import CryptomatorFileProvider

class FileProviderDecoratorMock: FileProviderDecorator {
	let internalProvider: CloudProviderMock
	override var provider: CloudProvider {
		return internalProvider
	}

	let tmpDirURL: URL

	init(with provider: CloudProviderMock, for domain: NSFileProviderDomain, with manager: NSFileProviderManager) throws {
		self.internalProvider = provider
		self.tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbPath = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		try super.init(for: domain, with: manager, dbPath: dbPath)
		self.homeRoot = URL(fileURLWithPath: "/", isDirectory: true)
	}

	override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
		guard let itemMetadata = try? getCachedMetadata(for: identifier) else {
			return nil
		}
		let perItemDirectory = tmpDirURL.appendingPathComponent(identifier.rawValue, isDirectory: true)
		return perItemDirectory.appendingPathComponent(itemMetadata.name, isDirectory: false)
	}
}
