//
//  ProgressManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 06.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

protocol ProgressManager {
	/**
	 Returns the progress for the given `itemIdentifier` - `nil` if no progress could be found for the given `itemIdentifier`.
	 */
	func getProgress(for itemIdentifier: NSFileProviderItemIdentifier) -> Progress?

	/**
	 Saves the progress for the given `itemIdentifier`.

	 - Note: If a progress object already exists for the given `itemIdentifier`, it will be replaced.
	 */
	func saveProgress(_ progress: Progress, for itemIdentifier: NSFileProviderItemIdentifier)
}

class InMemoryProgressManager: ProgressManager {
	static let shared = InMemoryProgressManager()

	private let queue = DispatchQueue(label: "InMemoryProgressManager", attributes: .concurrent)
	private lazy var progressDictionary = [NSFileProviderItemIdentifier: Progress]()

	func getProgress(for itemIdentifier: NSFileProviderItemIdentifier) -> Progress? {
		return queue.sync {
			progressDictionary[itemIdentifier]
		}
	}

	func saveProgress(_ progress: Progress, for itemIdentifier: NSFileProviderItemIdentifier) {
		queue.async(flags: .barrier) {
			self.progressDictionary[itemIdentifier] = progress
		}
	}
}
