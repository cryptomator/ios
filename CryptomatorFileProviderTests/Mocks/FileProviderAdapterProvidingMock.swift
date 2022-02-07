//
//  FileProviderAdapterProvidingMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
@testable import CryptomatorFileProvider

// swiftlint:disable all

final class FileProviderAdapterProvidingMock: FileProviderAdapterProviding {
	// MARK: - unlockMonitor

	var unlockMonitorGetterCallsCount = 0
	var unlockMonitor: UnlockMonitorType {
		get {
			unlockMonitorGetterCallsCount += 1
			return underlyingUnlockMonitor
		}
		set(value) { underlyingUnlockMonitor = value }
	}

	private var underlyingUnlockMonitor: UnlockMonitorType!

	// MARK: - getAdapter

	var getAdapterForDomainDbPathDelegateNotificatorThrowableError: Error?
	var getAdapterForDomainDbPathDelegateNotificatorCallsCount = 0
	var getAdapterForDomainDbPathDelegateNotificatorCalled: Bool {
		getAdapterForDomainDbPathDelegateNotificatorCallsCount > 0
	}

	var getAdapterForDomainDbPathDelegateNotificatorReceivedArguments: (domain: NSFileProviderDomain, dbPath: URL, delegate: LocalURLProvider?, notificator: FileProviderNotificatorType)?
	var getAdapterForDomainDbPathDelegateNotificatorReceivedInvocations: [(domain: NSFileProviderDomain, dbPath: URL, delegate: LocalURLProvider?, notificator: FileProviderNotificatorType)] = []
	var getAdapterForDomainDbPathDelegateNotificatorReturnValue: FileProviderAdapterType!
	var getAdapterForDomainDbPathDelegateNotificatorClosure: ((NSFileProviderDomain, URL, LocalURLProvider?, FileProviderNotificatorType) throws -> FileProviderAdapterType)?

	func getAdapter(forDomain domain: NSFileProviderDomain, dbPath: URL, delegate: LocalURLProvider?, notificator: FileProviderNotificatorType) throws -> FileProviderAdapterType {
		if let error = getAdapterForDomainDbPathDelegateNotificatorThrowableError {
			throw error
		}
		getAdapterForDomainDbPathDelegateNotificatorCallsCount += 1
		getAdapterForDomainDbPathDelegateNotificatorReceivedArguments = (domain: domain, dbPath: dbPath, delegate: delegate, notificator: notificator)
		getAdapterForDomainDbPathDelegateNotificatorReceivedInvocations.append((domain: domain, dbPath: dbPath, delegate: delegate, notificator: notificator))
		return try getAdapterForDomainDbPathDelegateNotificatorClosure.map({ try $0(domain, dbPath, delegate, notificator) }) ?? getAdapterForDomainDbPathDelegateNotificatorReturnValue
	}
}

// swiftlint:enable all
