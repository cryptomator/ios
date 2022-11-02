//
//  MaintenanceModeHelperServiceSource.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 26.10.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import FileProvider
import Foundation
import GRDB

public class MaintenanceModeHelperServiceSource: ServiceSource, MaintenanceModeHelper {
	private let databaseHelper: DatabaseHelping
	private let providerIdentifier: String
	private let domain: NSFileProviderDomain

	public init(databaseHelper: DatabaseHelping, providerIdentifier: String, domain: NSFileProviderDomain) {
		self.databaseHelper = databaseHelper
		self.providerIdentifier = providerIdentifier
		self.domain = domain
		super.init(serviceName: .maintenanceModeHelper, exportedInterface: .init(with: MaintenanceModeHelper.self))
	}

	// MARK: - MaintenanceModeHelper

	public func enableMaintenanceMode(reply: @escaping (NSError?) -> Void) {
		let database: DatabaseWriter
		do {
			database = try getDatabaseWriter()
		} catch {
			DDLogError("Get database failed for enableMaintenanceMode with error: \(error)")
			reply(error as NSError)
			return
		}
		let maintenanceManager = MaintenanceDBManager(database: database)
		do {
			try maintenanceManager.enableMaintenanceMode()
		} catch {
			reply(error as NSError)
			return
		}
		reply(nil)
	}

	public func disableMaintenanceMode(reply: @escaping (NSError?) -> Void) {
		let database: DatabaseWriter
		do {
			database = try getDatabaseWriter()
		} catch {
			DDLogError("Get database failed for disableMaintenanceMode with error: \(error)")
			reply(error as NSError)
			return
		}
		let maintenanceManager = MaintenanceDBManager(database: database)
		do {
			try maintenanceManager.disableMaintenanceMode()
		} catch {
			reply(error as NSError)
			return
		}
		reply(nil)
	}

	private func getDatabaseWriter() throws -> DatabaseWriter {
		let databaseURL = databaseHelper.getDatabaseURL(for: domain)
		return try databaseHelper.getMigratedDB(at: databaseURL, purposeIdentifier: providerIdentifier)
	}
}
