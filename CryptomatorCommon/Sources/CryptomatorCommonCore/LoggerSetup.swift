//
//  LoggerSetup.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import Foundation

public enum LoggerSetup {
	public static var oneTimeSetup: () -> Void = {
		let fileLogger = DDFileLogger.sharedInstance
		fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hour rolling
		fileLogger.logFileManager.maximumNumberOfLogFiles = 7
		DDLog.add(DDOSLogger.sharedInstance)
		DDLog.add(fileLogger)
		CloudAccessDDLog.add(DDOSLogger.sharedInstance)
		CloudAccessDDLog.add(fileLogger)
		setDynamicLogLevel(debugModeEnabled: CryptomatorUserDefaults.shared.debugModeEnabled)
		return {}
	}()

	public static func setDynamicLogLevel(debugModeEnabled: Bool) {
		dynamicLogLevel = debugModeEnabled ? .debug : .error
		dynamicCloudAccessLogLevel = debugModeEnabled ? .debug : .error
	}
}

public extension DDFileLogger {
	static var sharedInstance: DDFileLogger = {
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName) else {
			print("containerURL is nil")
			return DDFileLogger()
		}
		let logsDirectory = containerURL.appendingPathComponent("Logs")
		try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: false, attributes: nil)
		let logFileManager = DDLogFileManagerDefault(logsDirectory: logsDirectory.path)
		return DDFileLogger(logFileManager: logFileManager)
	}()
}
