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

	var getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorThrowableError: Error?
	var getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorCallsCount = 0
	var getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorCalled: Bool {
		getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorCallsCount > 0
	}

	var getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReceivedArguments: (domain: NSFileProviderDomain, dbPath: URL, delegate: LocalURLProviderType, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator)?
	var getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReceivedInvocations: [(domain: NSFileProviderDomain, dbPath: URL, delegate: LocalURLProviderType, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator)] = []
	var getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue: FileProviderAdapterType!
	var getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorClosure: ((NSFileProviderDomain, URL, LocalURLProviderType, FileProviderNotificatorType, SessionTaskRegistrator) throws -> FileProviderAdapterType)?

	func getAdapter(forDomain domain: NSFileProviderDomain, dbPath: URL, delegate: LocalURLProviderType, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator) throws -> FileProviderAdapterType {
		if let error = getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorThrowableError {
			throw error
		}
		getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorCallsCount += 1
		getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReceivedArguments = (domain: domain, dbPath: dbPath, delegate: delegate, notificator: notificator, taskRegistrator: taskRegistrator)
		getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReceivedInvocations.append((domain: domain, dbPath: dbPath, delegate: delegate, notificator: notificator, taskRegistrator: taskRegistrator))
		return try getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorClosure.map({ try $0(domain, dbPath, delegate, notificator, taskRegistrator) }) ?? getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue
	}
}

// swiftlint:enable all
