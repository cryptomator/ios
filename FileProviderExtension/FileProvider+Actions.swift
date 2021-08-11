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
		DDLogInfo("FPExt: importDocument(at: \(fileURL), toParentItemIdentifier: \(parentItemIdentifier.rawValue))")
		let adapter: FileProviderAdapter
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		adapter.importDocument(at: fileURL, toParentItemIdentifier: parentItemIdentifier, completionHandler: completionHandler)
	}

	override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogInfo("FPExt: createDirectory(withName: \(directoryName), inParentItemIdentifier: \(parentItemIdentifier.rawValue))")
		let adapter: FileProviderAdapter
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		adapter.createDirectory(withName: directoryName, inParentItemIdentifier: parentItemIdentifier, completionHandler: completionHandler)
	}

	override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogInfo("FPExt: renameItem(withIdentifier: \(itemIdentifier.rawValue), toName: \(itemName))")
		let adapter: FileProviderAdapter
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		adapter.renameItem(withIdentifier: itemIdentifier, toName: itemName, completionHandler: completionHandler)
	}

	override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DDLogInfo("FPExt: reparentItem(withIdentifier: \(itemIdentifier.rawValue), toParentItemWithIdentifier: \(parentItemIdentifier.rawValue))")
		let adapter: FileProviderAdapter
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(nil, error)
		}
		adapter.reparentItem(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: newName, completionHandler: completionHandler)
	}

	override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
		DDLogInfo("FPExt: deleteItem(withIdentifier: \(itemIdentifier.rawValue))")
		let adapter: FileProviderAdapter
		do {
			adapter = try getAdapterWithWrappedError()
		} catch {
			return completionHandler(error)
		}
		adapter.deleteItem(withIdentifier: itemIdentifier, completionHandler: completionHandler)
	}
}
