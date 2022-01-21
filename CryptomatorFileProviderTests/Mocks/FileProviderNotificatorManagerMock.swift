//
//  FileProviderNotificatorManagerMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 21.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
@testable import CryptomatorFileProvider

final class FileProviderNotificatorManagerTypeMock: FileProviderNotificatorManagerType {
	// MARK: - getFileProviderNotificator

	var getFileProviderNotificatorForThrowableError: Error?
	var getFileProviderNotificatorForCallsCount = 0
	var getFileProviderNotificatorForCalled: Bool {
		getFileProviderNotificatorForCallsCount > 0
	}

	var getFileProviderNotificatorForReceivedDomain: NSFileProviderDomain?
	var getFileProviderNotificatorForReceivedInvocations: [NSFileProviderDomain] = []
	var getFileProviderNotificatorForReturnValue: FileProviderNotificatorType!
	var getFileProviderNotificatorForClosure: ((NSFileProviderDomain) throws -> FileProviderNotificatorType)?

	func getFileProviderNotificator(for domain: NSFileProviderDomain) throws -> FileProviderNotificatorType {
		if let error = getFileProviderNotificatorForThrowableError {
			throw error
		}
		getFileProviderNotificatorForCallsCount += 1
		getFileProviderNotificatorForReceivedDomain = domain
		getFileProviderNotificatorForReceivedInvocations.append(domain)
		return try getFileProviderNotificatorForClosure.map({ try $0(domain) }) ?? getFileProviderNotificatorForReturnValue
	}
}
