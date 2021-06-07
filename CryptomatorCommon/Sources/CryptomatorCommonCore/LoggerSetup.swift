//
//  LoggerSetup.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjack
import CocoaLumberjackSwift
import Foundation

public enum LoggerSetup {
	public static var oneTimeSetup: () -> Void = {
		let fileLogger = DDFileLogger.sharedInstance
		fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hour rolling
		fileLogger.logFileManager.maximumNumberOfLogFiles = 7
		DDLog.add(DDOSLogger.sharedInstance)
		DDLog.add(fileLogger)
		return {}
	}()
}

extension DDFileLogger {
	public static var sharedInstance: DDFileLogger = {
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName) else {
			print("containerURL is nil")
			return DDFileLogger()
		}
		let logsDirectory = containerURL.appendingPathComponent("Logs")
		do {
			try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: false, attributes: nil)
		} catch {
			print(error)
		}
		print("LogsDirectory: \(logsDirectory.path)")
		let logFileManager = DDLogFileManagerDefault(logsDirectory: logsDirectory.path)
		return DDFileLogger(logFileManager: logFileManager)
	}()
}
