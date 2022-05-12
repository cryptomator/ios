//
//  ProgressManagerMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 09.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
@testable import CryptomatorFileProvider

final class ProgressManagerMock: ProgressManager {
	// MARK: - getProgress

	var getProgressForCallsCount = 0
	var getProgressForCalled: Bool {
		getProgressForCallsCount > 0
	}

	var getProgressForReceivedItemIdentifier: NSFileProviderItemIdentifier?
	var getProgressForReceivedInvocations: [NSFileProviderItemIdentifier] = []
	var getProgressForReturnValue: Progress?
	var getProgressForClosure: ((NSFileProviderItemIdentifier) -> Progress?)?

	func getProgress(for itemIdentifier: NSFileProviderItemIdentifier) -> Progress? {
		getProgressForCallsCount += 1
		getProgressForReceivedItemIdentifier = itemIdentifier
		getProgressForReceivedInvocations.append(itemIdentifier)
		return getProgressForClosure.map({ $0(itemIdentifier) }) ?? getProgressForReturnValue
	}

	// MARK: - saveProgress

	var saveProgressForCallsCount = 0
	var saveProgressForCalled: Bool {
		saveProgressForCallsCount > 0
	}

	var saveProgressForReceivedArguments: (progress: Progress, itemIdentifier: NSFileProviderItemIdentifier)?
	var saveProgressForReceivedInvocations: [(progress: Progress, itemIdentifier: NSFileProviderItemIdentifier)] = []
	var saveProgressForClosure: ((Progress, NSFileProviderItemIdentifier) -> Void)?

	func saveProgress(_ progress: Progress, for itemIdentifier: NSFileProviderItemIdentifier) {
		saveProgressForCallsCount += 1
		saveProgressForReceivedArguments = (progress: progress, itemIdentifier: itemIdentifier)
		saveProgressForReceivedInvocations.append((progress: progress, itemIdentifier: itemIdentifier))
		saveProgressForClosure?(progress, itemIdentifier)
	}
}
