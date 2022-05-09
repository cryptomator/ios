//
//  UploadRetryingServiceSource.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 03.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import Foundation

public class UploadRetryingServiceSource: ServiceSource, UploadRetrying {
	private let adapterManager: FileProviderAdapterProviding
	private let domain: NSFileProviderDomain
	private let notificator: FileProviderNotificatorType
	private let dbPath: URL
	private let localURLProvider: LocalURLProviderType
	private let progressManager: ProgressManager

	public convenience init(domain: NSFileProviderDomain, notificator: FileProviderNotificatorType, dbPath: URL, delegate: LocalURLProviderType) {
		self.init(domain: domain,
		          notificator: notificator,
		          dbPath: dbPath,
		          delegate: delegate,
		          adapterManager: FileProviderAdapterManager.shared)
	}

	init(domain: NSFileProviderDomain, notificator: FileProviderNotificatorType, dbPath: URL, delegate: LocalURLProviderType, adapterManager: FileProviderAdapterProviding = FileProviderAdapterManager.shared, progressManager: ProgressManager = InMemoryProgressManager.shared) {
		self.domain = domain
		self.notificator = notificator
		self.dbPath = dbPath
		self.localURLProvider = delegate
		self.adapterManager = adapterManager
		self.progressManager = progressManager
		super.init(serviceName: .uploadRetryingService, exportedInterface: NSXPCInterface(with: UploadRetrying.self))
	}

	public func retryUpload(for itemIdentifiers: [NSFileProviderItemIdentifier], reply: @escaping (Error?) -> Void) {
		let adapter: FileProviderAdapterType
		do {
			adapter = try adapterManager.getAdapter(forDomain: domain,
			                                        dbPath: dbPath,
			                                        delegate: localURLProvider,
			                                        notificator: notificator)
		} catch {
			reply(error)
			return
		}
		for itemIdentifier in itemIdentifiers {
			adapter.retryUpload(for: itemIdentifier)
		}
		reply(nil)
	}

	public func getCurrentFractionalUploadProgress(for itemIdentifier: NSFileProviderItemIdentifier, reply: @escaping (NSNumber?) -> Void) {
		let progress = progressManager.getProgress(for: itemIdentifier)
		reply(progress?.fractionCompleted as NSNumber?)
	}
}
