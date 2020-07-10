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
		print("importDocument called")
		guard let decorator = self.decorator else {
			return completionHandler(nil, NSFileProviderError(.notAuthenticated))
		}
		DispatchQueue.main.async {
			autoreleasepool {
				if !fileURL.startAccessingSecurityScopedResource() {
					return completionHandler(nil, NSFileProviderError(.noSuchItem))
				}
				let item: FileProviderItem
				do {
					item = try decorator.createPlaceholderItemForFile(for: fileURL, in: parentItemIdentifier)
				} catch let error as NSError {
					if error.domain == NSFileProviderErrorDomain, error.code == NSFileProviderError.filenameCollision.rawValue {
						return completionHandler(nil, error)
					}
					return completionHandler(nil, NSFileProviderError(.noSuchItem))
				}
				guard let localURL = self.urlForItem(withPersistentIdentifier: item.itemIdentifier) else {
					return completionHandler(nil, NSFileProviderError(.noSuchItem))
				}
				var fileManagerError: NSFileProviderError?
				NSFileCoordinator().coordinate(readingItemAt: fileURL, options: .withoutChanges, error: nil) { _ in
					// TODO: better error handling, createDirectory does not need Coordinator!
					do {
						try self.fileManager.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
						try self.fileManager.copyItem(at: fileURL, to: localURL)
						print("copied item to: \(localURL)")
					} catch {
						print("got error in Coordinator: \(error)")
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
				decorator.uploadFile(with: localURL, identifier: item.itemIdentifier).then { _ in
					// TODO: Signal Enumerator here
					print("upload completed")
				}.catch { error in
					print("uploadFile error: \(error)")
				}
			}
		}
	}
}
