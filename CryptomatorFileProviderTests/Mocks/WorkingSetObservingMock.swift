//
//  WorkingSetObservingMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
@testable import CryptomatorFileProvider

final class WorkingSetObservingMock: WorkingSetObserving {
	// MARK: - startObservation

	var startObservationCallsCount = 0
	var startObservationCalled: Bool {
		startObservationCallsCount > 0
	}

	var startObservationClosure: (() -> Void)?

	func startObservation() {
		startObservationCallsCount += 1
		startObservationClosure?()
	}
}
