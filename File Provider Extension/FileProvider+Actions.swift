//
//  FileProvider+Actions.swift
//  File Provider Extension
//
//  Created by Philipp Schmid on 03.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import FileProvider
import Foundation
extension FileProviderExtension {
	override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DispatchQueue.main.async {
			autoreleasepool {
				if !fileURL.startAccessingSecurityScopedResource() {
					return completionHandler(nil, NSFileProviderError(.noSuchItem))
				}
				let item: FileProviderItem
				do {
					item = try self.decorator!.createPlaceholderItemForFile(for: fileURL, in: parentItemIdentifier)
				} catch {
					return completionHandler(nil, NSFileProviderError(.noSuchItem))
				}
				guard let localURL = self.urlForItem(withPersistentIdentifier: item.itemIdentifier) else {
					return completionHandler(nil, NSFileProviderError(.noSuchItem))
				}
				var fileManagerError: NSFileProviderError?
				NSFileCoordinator().coordinate(readingItemAt: fileURL, options: .withoutChanges, error: nil) { _ in
					// TODO: better error handling
					do {
						try self.fileManager.copyItem(at: fileURL, to: localURL)
					} catch {
						fileManagerError = NSFileProviderError(.noSuchItem)
					}
				}

				fileURL.stopAccessingSecurityScopedResource()
				if let error = fileManagerError {
					try? self.decorator!.removePlaceholderItem(with: item.itemIdentifier) // we report already an error
					completionHandler(nil, error)
					return
				}
				completionHandler(item, nil)

				// Network Stuff
//				do{
//					try decorator!.
//				} catch{
//
//				}
			}
		}
	}
}
