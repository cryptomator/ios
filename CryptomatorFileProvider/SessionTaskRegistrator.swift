//
//  SessionTaskRegistrator.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 30.11.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

public protocol SessionTaskRegistrator {
	func register(_ task: SessionTask, forItemWithIdentifier identifier: NSFileProviderItemIdentifier, completionHandler completion: @escaping (Error?) -> Void)
}

public protocol SessionTask {}

extension URLSessionTask: SessionTask {}

extension NSFileProviderManager: SessionTaskRegistrator {
	public func register(_ task: SessionTask, forItemWithIdentifier identifier: NSFileProviderItemIdentifier, completionHandler completion: @escaping (Error?) -> Void) {
		guard let urlSessionTask = task as? URLSessionTask else {
			completion(UnexpectedSessionTaskTypeError())
			return
		}
		register(urlSessionTask, forItemWithIdentifier: identifier, completionHandler: completion)
	}
}

struct UnexpectedSessionTaskTypeError: Error {}
