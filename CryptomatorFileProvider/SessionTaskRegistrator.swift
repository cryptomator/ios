//
//  SessionTaskRegistrator.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 30.11.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

public protocol SessionTaskRegistrator: Sendable {
	func register(_ task: URLSessionTask, forItemWithIdentifier identifier: NSFileProviderItemIdentifier) async throws
}

/// @unchecked Sendable: used only to call `register`
public struct FileProviderManagerTaskRegistrator: SessionTaskRegistrator, @unchecked Sendable {
	private let manager: NSFileProviderManager

	public init(manager: NSFileProviderManager) {
		self.manager = manager
	}

	public func register(_ task: URLSessionTask, forItemWithIdentifier identifier: NSFileProviderItemIdentifier) async throws {
		try await manager.register(task, forItemWithIdentifier: identifier)
	}
}
