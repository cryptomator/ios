//
//  FileProvider+Actions.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 03.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorFileProvider
import FileProvider
import Foundation

extension FileProviderExtension {
	override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogDebug("FPExt: importDocument(at: \(fileURL), toParentItemIdentifier: \(parentItemIdentifier.rawValue)) called")
		let adapter: FileProviderAdapterType
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		// nonisolated(unsafe): fileproviderd reply block, invoked once from any thread
		nonisolated(unsafe) let completionHandler = completionHandler
		adapter.importDocument(at: fileURL, toParentItemIdentifier: parentItemIdentifier, completionHandler: { completionHandler($0, $1) })
	}

	override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogDebug("FPExt: createDirectory(withName: \(directoryName), inParentItemIdentifier: \(parentItemIdentifier.rawValue)) called")
		let adapter: FileProviderAdapterType
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		// nonisolated(unsafe): fileproviderd reply block, invoked once from any thread
		nonisolated(unsafe) let completionHandler = completionHandler
		adapter.createDirectory(withName: directoryName, inParentItemIdentifier: parentItemIdentifier, completionHandler: { completionHandler($0, $1) })
	}

	override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogDebug("FPExt: renameItem(withIdentifier: \(itemIdentifier.rawValue), toName: \(itemName)) called")
		let adapter: FileProviderAdapterType
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		// nonisolated(unsafe): fileproviderd reply block, invoked once from any thread
		nonisolated(unsafe) let completionHandler = completionHandler
		adapter.renameItem(withIdentifier: itemIdentifier, toName: itemName, completionHandler: { completionHandler($0, $1) })
	}

	override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogInfo("FPExt: reparentItem(withIdentifier: \(itemIdentifier.rawValue), toParentItemWithIdentifier: \(parentItemIdentifier.rawValue)) called")
		let adapter: FileProviderAdapterType
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		// nonisolated(unsafe): fileproviderd reply block, invoked once from any thread
		nonisolated(unsafe) let completionHandler = completionHandler
		adapter.reparentItem(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: newName, completionHandler: { completionHandler($0, $1) })
	}

	override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
		DDLogDebug("FPExt: deleteItem(withIdentifier: \(itemIdentifier.rawValue)) called")
		let adapter: FileProviderAdapterType
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(error)
		}
		// nonisolated(unsafe): fileproviderd reply block, invoked once from any thread
		nonisolated(unsafe) let completionHandler = completionHandler
		adapter.deleteItem(withIdentifier: itemIdentifier, completionHandler: { completionHandler($0) })
	}

	override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogDebug("FPExt: setFavoriteRank(_: \(String(describing: favoriteRank)), forItemIdentifier: \(itemIdentifier.rawValue)) called")
		let adapter: FileProviderAdapterType
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		adapter.setFavoriteRank(favoriteRank, forItemIdentifier: itemIdentifier, completionHandler: completionHandler)
	}

	override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogDebug("FPExt: setTagData(_: \(String(describing: tagData)), forItemIdentifier: \(itemIdentifier.rawValue)) called")
		let adapter: FileProviderAdapterType
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		adapter.setTagData(tagData, forItemIdentifier: itemIdentifier, completionHandler: completionHandler)
	}
}
