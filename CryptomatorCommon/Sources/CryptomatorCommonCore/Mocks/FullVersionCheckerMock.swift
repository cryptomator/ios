//
//  FullVersionCheckerMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 02.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

final class FullVersionCheckerMock: FullVersionChecker {
	var isFullVersion: Bool = false
	var hasExpiredTrial: Bool = false
}
