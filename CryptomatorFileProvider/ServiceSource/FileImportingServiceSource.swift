//
//  FileImportingServiceSource.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 13.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import FileProvider
import Foundation

public class FileImportingServiceSource: ServiceSource, FileImporting {
	private let domain: NSFileProviderDomain
	private let notificator: FileProviderNotificatorType
	private let dbPath: URL
	private let localURLProvider: LocalURLProviderType
	private let adapterManager: FileProviderAdapterProviding

	public convenience init(domain: NSFileProviderDomain, notificator: FileProviderNotificatorType, dbPath: URL, delegate: LocalURLProviderType) {
		self.init(domain: domain,
		          notificator: notificator,
		          dbPath: dbPath,
		          delegate: delegate,
		          adapterManager: FileProviderAdapterManager.shared)
	}

	init(domain: NSFileProviderDomain, notificator: FileProviderNotificatorType, dbPath: URL, delegate: LocalURLProviderType, adapterManager: FileProviderAdapterProviding) {
		self.domain = domain
		self.notificator = notificator
		self.dbPath = dbPath
		self.localURLProvider = delegate
		self.adapterManager = adapterManager
		super.init(serviceName: .fileImporting, exportedInterface: NSXPCInterface(with: FileImporting.self))
	}

	public func getIdentifierForItem(at path: String, reply: @escaping (NSString?, NSError?) -> Void) {
		Task {
			do {
				let identifier = try await getIdentifierForItem(at: path)
				reply(identifier, nil)
			} catch {
				reply(nil, error as NSError)
			}
		}
	}

	func getIdentifierForItem(at path: String) async throws -> NSString {
		let adapter: FileProviderAdapterType
		do {
			adapter = try adapterManager.getAdapter(forDomain: domain,
			                                        dbPath: dbPath,
			                                        delegate: localURLProvider,
			                                        notificator: notificator)
		} catch {
			throw ErrorWrapper.wrapError(error, domain: domain)._nsError
		}
		let cloudPath = CloudPath(path)
		let itemIdentifier = try await adapter.getItemIdentifier(for: cloudPath)
		return itemIdentifier.rawValue as NSString
	}

	public func importFile(at localURL: URL, toParentItemIdentifier parentItemIdentifier: String, reply: @escaping (NSError?) -> Void) {
		Task {
			do {
				try await importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier)
				reply(nil)
			} catch let error as NSError {
				var userInfo = error.userInfo
				userInfo[NSFileProviderErrorItemKey] = nil
				let modifiedError = NSError(domain: error.domain, code: error.code, userInfo: userInfo)
				reply(modifiedError)
			}
		}
	}

	func importFile(at localURL: URL, toParentItemIdentifier parentItemIdentifier: String) async throws {
		let adapter: FileProviderAdapterType
		do {
			adapter = try adapterManager.getAdapter(forDomain: domain,
			                                        dbPath: dbPath,
			                                        delegate: localURLProvider,
			                                        notificator: notificator)
		} catch {
			throw ErrorWrapper.wrapError(error, domain: domain)._nsError
		}
		let parentItemIdentifier = NSFileProviderItemIdentifier(parentItemIdentifier)
		_ = try await adapter.importDocument(at: localURL, toParentItemIdentifier: parentItemIdentifier)
	}
}
