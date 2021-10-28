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

public class LogLevelUpdatingServiceSource: NSObject, NSFileProviderServiceSource, NSXPCListenerDelegate, LogLevelUpdating {
	public var serviceName: NSFileProviderServiceName {
		LogLevelUpdatingService.name
	}

	private lazy var listener: NSXPCListener = {
		let listener = NSXPCListener.anonymous()
		listener.delegate = self
		listener.resume()
		return listener
	}()

	private let cryptomatorSettings: CryptomatorSettings

	init(cryptomatorSettings: CryptomatorSettings) {
		self.cryptomatorSettings = cryptomatorSettings
	}

	override public convenience init() {
		self.init(cryptomatorSettings: CryptomatorUserDefaults.shared)
	}

	public func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		return listener.endpoint
	}

	// MARK: - NSXPCListenerDelegate

	public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		newConnection.exportedInterface = NSXPCInterface(with: LogLevelUpdating.self)
		newConnection.exportedObject = self
		newConnection.resume()
		weak var weakConnection = newConnection
		newConnection.interruptionHandler = {
			weakConnection?.invalidate()
		}
		return true
	}

	// MARK: - LogLevelUpdating

	public func logLevelUpdated() {
		LoggerSetup.setDynamicLogLevel(debugModeEnabled: cryptomatorSettings.debugModeEnabled)
	}
}
