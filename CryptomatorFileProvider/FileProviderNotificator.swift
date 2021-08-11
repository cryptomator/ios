//
//  FileProviderNotificator.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 13.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import FileProvider
import Foundation

public class FileProviderNotificator: FileProviderItemUpdateDelegate {
	public var fileProviderSignalDeleteContainerItemIdentifier = [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier]()
	public var fileProviderSignalUpdateContainerItem = [NSFileProviderItemIdentifier: FileProviderItem]()
	public var fileProviderSignalDeleteWorkingSetItemIdentifier = [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier]()
	public var fileProviderSignalUpdateWorkingSetItem = [NSFileProviderItemIdentifier: FileProviderItem]()

	public private(set) var currentAnchor: UInt64

	private let manager: NSFileProviderManager

	public init(manager: NSFileProviderManager) {
		self.manager = manager
		self.currentAnchor = 0
	}

	/**
	 Signal the enumerator with a small delay of 0.2 seconds, because otherwise some items in the `FileProvider` are not updated correctly.
	 */
	public func signalEnumerator(for containerItemIdentifiers: [NSFileProviderItemIdentifier]) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			self.currentAnchor += 1
			for containerItemIdentifier in containerItemIdentifiers {
				self.manager.signalEnumerator(for: containerItemIdentifier) { error in
					if let error = error {
						DDLogDebug("SignalEnumerator for \(containerItemIdentifier) returned error: \(error)")
					}
				}
			}
		}
	}

	func signalUpdate(for item: FileProviderItem) {
		fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
		signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
	}
}

protocol FileProviderItemUpdateDelegate: AnyObject {
	func signalUpdate(for item: FileProviderItem)
}
