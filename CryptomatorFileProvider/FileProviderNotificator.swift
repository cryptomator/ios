//
//  FileProviderNotificator.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 13.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
public class FileProviderNotificator {
	private let manager: NSFileProviderManager
	public private(set) var currentAnchor: UInt64
	public var fileProviderSignalDeleteContainerItemIdentifier = [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier]()
	public var fileProviderSignalUpdateContainerItem = [NSFileProviderItemIdentifier: FileProviderItem]()
	public var fileProviderSignalDeleteWorkingSetItemIdentifier = [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier]()
	public var fileProviderSignalUpdateWorkingSetItem = [NSFileProviderItemIdentifier: FileProviderItem]()

	public init(manager: NSFileProviderManager) {
		self.manager = manager
		self.currentAnchor = 0
	}

	/**
	 Signal the Enumerator with a small delay of 0.2 seconds, because otherwise some items in the FileProvider are not updated correctly.
	 */
	public func signalEnumerator(for containerItemIdentifiers: [NSFileProviderItemIdentifier]) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			self.currentAnchor += 1
			for containerItemIdentifier in containerItemIdentifiers {
				self.manager.signalEnumerator(for: containerItemIdentifier) { error in
					if let error = error {
						print("SignalEnumerator for \(containerItemIdentifier) returned error: \(error)")
					}
				}
			}
		}
	}
}
