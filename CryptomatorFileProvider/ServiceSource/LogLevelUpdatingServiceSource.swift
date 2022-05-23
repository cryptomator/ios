//
//  LogLevelUpdatingServiceSource.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 11.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import FileProvider
import Foundation

public class LogLevelUpdatingServiceSource: ServiceSource, LogLevelUpdating {
	private let cryptomatorSettings: CryptomatorSettings

	init(cryptomatorSettings: CryptomatorSettings) {
		self.cryptomatorSettings = cryptomatorSettings
		super.init(serviceName: .logLevelUpdating, exportedInterface: NSXPCInterface(with: LogLevelUpdating.self))
	}

	public convenience init() {
		self.init(cryptomatorSettings: CryptomatorUserDefaults.shared)
	}

	// MARK: - LogLevelUpdating

	public func logLevelUpdated() {
		LoggerSetup.setDynamicLogLevel(debugModeEnabled: cryptomatorSettings.debugModeEnabled)
	}
}
