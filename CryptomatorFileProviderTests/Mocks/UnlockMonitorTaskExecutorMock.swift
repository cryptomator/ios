//
//  UnlockMonitorTaskExecutorMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.02.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
@testable import CryptomatorFileProvider

final class UnlockMonitorTaskExecutorMock: UnlockMonitorTaskExecutorType {
	// MARK: - runningBiometricalUnlock

	var runningBiometricalUnlock: Bool {
		get { underlyingRunningBiometricalUnlock }
		set(value) { underlyingRunningBiometricalUnlock = value }
	}

	private var underlyingRunningBiometricalUnlock: Bool!

	// MARK: - execute

	var executeCallsCount = 0
	var executeCalled: Bool {
		executeCallsCount > 0
	}

	var executeReceivedWork: (() -> Void)?
	var executeReceivedInvocations: [() -> Void] = []
	var executeClosure: ((@escaping () -> Void) -> Void)?

	func execute(_ work: @escaping () -> Void) {
		executeCallsCount += 1
		executeReceivedWork = work
		executeReceivedInvocations.append(work)
		executeClosure?(work)
	}
}
