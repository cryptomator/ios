//
//  FileProvider+Actions.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 03.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjack
import CocoaLumberjackSwift
import CryptomatorFileProvider
import FileProvider
import Foundation

extension FileProviderExtension {
	// swiftlint:disable:next function_body_length
	override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogInfo("FPExt: importDocument(at: \(fileURL), toParentItemIdentifier: \(parentItemIdentifier.rawValue))")
		guard let decorator = self.decorator else {
			return completionHandler(nil, NSFileProviderError(.notAuthenticated))
		}
		DispatchQueue.main.async {
			autoreleasepool {
				let stopAccess = fileURL.startAccessingSecurityScopedResource()
				let item: FileProviderItem
				do {
					item = try decorator.createPlaceholderItemForFile(for: fileURL, in: parentItemIdentifier)
				} catch let error as NSError {
					if error.domain == NSFileProviderErrorDomain, error.code == NSFileProviderError.filenameCollision.rawValue {
						DDLogInfo("FPExt: filenameCollision for: \(fileURL.lastPathComponent)")
						return completionHandler(nil, error)
					}
					return completionHandler(nil, NSFileProviderError(.noSuchItem))
				}
				guard let localURL = self.urlForItem(withPersistentIdentifier: item.itemIdentifier) else {
					return completionHandler(nil, NSFileProviderError(.noSuchItem))
				}
				var fileManagerError: NSError?
				self.fileCoordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, error: nil) { _ in
					// TODO: better error handling, createDirectory does not need Coordinator!
					do {
						try self.fileManager.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
						try self.fileManager.copyItem(at: fileURL, to: localURL)
					} catch let error as NSError {
						fileManagerError = error as NSError
					}
				}
				if stopAccess {
					fileURL.stopAccessingSecurityScopedResource()
				}
				if let error = fileManagerError {
					try? decorator.reportLocalUploadError(for: item.itemIdentifier, error: error) // we report already an error
					completionHandler(nil, error)
					return
				}
				let metadata: ItemMetadata
				do {
					metadata = try decorator.registerFileInUploadQueue(with: localURL, identifier: item.itemIdentifier)
				} catch {
					completionHandler(nil, error)
					return
				}
				completionHandler(item, nil)

				// Network Stuff
				decorator.uploadFile(with: localURL, itemMetadata: metadata).then { item in
					self.notificator?.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
					self.notificator?.signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
				}.catch { error in
					DDLogError("FPExt:(importDocument) uploadFile failed: \(error)")
				}
			}
		}
	}

	override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogInfo("FPExt: createDirectory(withName: \(directoryName), inParentItemIdentifier: \(parentItemIdentifier.rawValue))")
		guard let decorator = self.decorator else {
			return completionHandler(nil, NSFileProviderError(.notAuthenticated))
		}
		let placeholderItem: FileProviderItem
		do {
			placeholderItem = try decorator.createPlaceholderItemForFolder(withName: directoryName, in: parentItemIdentifier)
		} catch {
			return completionHandler(nil, error)
		}
		completionHandler(placeholderItem, nil)
		decorator.createFolderInCloud(for: placeholderItem).then { item in
			self.notificator?.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
			self.notificator?.signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
		}.catch { error in
			DDLogError("FPExt: createFolderInCloud failed: \(error)")
		}
	}

	override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogInfo("FPExt: renameItem(withIdentifier: \(itemIdentifier.rawValue), toName: \(itemName))")
		guard let decorator = self.decorator else {
			return completionHandler(nil, NSFileProviderError(.notAuthenticated))
		}
		do {
			let item = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: nil, newName: itemName)
			completionHandler(item, nil)
		} catch {
			return completionHandler(nil, error)
		}

		decorator.moveItemInCloud(withIdentifier: itemIdentifier).then { item in
			self.notificator?.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
			self.notificator?.signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
		}.catch { error in
			DDLogError("FPExt:(moveItem) moveItemInCloud failed: \(error)")
		}
	}

	override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogInfo("FPExt: reparentItem(withIdentifier: \(itemIdentifier.rawValue), toParentItemWithIdentifier: \(parentItemIdentifier.rawValue))")
		guard let decorator = self.decorator else {
			return completionHandler(nil, NSFileProviderError(.notAuthenticated))
		}
		do {
			let item = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: newName)
			completionHandler(item, nil)
		} catch {
			return completionHandler(nil, error)
		}
		decorator.moveItemInCloud(withIdentifier: itemIdentifier).then { item in
			self.notificator?.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
			self.notificator?.signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
		}.catch { error in
			DDLogError("FPExt:(reparentItem) moveItemInCloud failed: \(error)")
		}
	}

	override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
		DDLogInfo("FPExt: deleteItem(withIdentifier: \(itemIdentifier.rawValue))")
		guard let decorator = self.decorator else {
			return completionHandler(NSFileProviderError(.notAuthenticated))
		}
		do {
			try decorator.deleteItemLocally(withIdentifier: itemIdentifier)
		} catch {
			return completionHandler(error)
		}
		completionHandler(nil)
		decorator.deleteItemInCloud(withIdentifier: itemIdentifier).catch { error in
			DDLogError("FPExt:(deleteItem) deleteItemInCloud failed: \(error)")
		}
	}
}
