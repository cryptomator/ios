//
//  MicrosoftGraphDriveManager.swift
//  CryptomatorCommon
//
//  Created by Majid Achhoud on 07.01.25.
//

import Foundation
import CryptomatorCloudAccessCore
import Combine

public enum MicrosoftGraphDriveManagerError: Error {
	case driveDuplicate(existingIdentifier: String)
}

public protocol MicrosoftGraphDriveManaging {
	var didUpdate: AnyPublisher<Void, Never> { get }

	func getDrivesFromKeychain(for accountUID: String) throws -> [MicrosoftGraphDrive]
	func saveDriveToKeychain(_ drive: MicrosoftGraphDrive, for accountUID: String) throws
	func removeDriveFromKeychain(with accountUID: String, driveIdentifier: String) throws
	func getDriveFromKeychain(for accountUID: String, driveID: String) throws -> MicrosoftGraphDrive?
}

public struct MicrosoftGraphDriveManager: MicrosoftGraphDriveManaging {
	public static let shared = MicrosoftGraphDriveManager(keychain: CryptomatorKeychain.microsoftGraph)

	public var didUpdate: AnyPublisher<Void, Never> {
		didUpdatePublisher.eraseToAnyPublisher()
	}

	private let keychain: CryptomatorKeychainType
	private let didUpdatePublisher = PassthroughSubject<Void, Never>()

	public func getDrivesFromKeychain(for accountUID: String) throws -> [MicrosoftGraphDrive] {
		return try keychain.getDriveIdentifiers(for: accountUID) ?? []
	}

	public func saveDriveToKeychain(_ drive: MicrosoftGraphDrive, for accountUID: String) throws {
		var allDrives = try getDrivesFromKeychain(for: accountUID)

		if allDrives.contains(where: { $0.identifier == drive.identifier }) {
			throw MicrosoftGraphDriveManagerError.driveDuplicate(existingIdentifier: drive.identifier)
		}

		allDrives.append(drive)
		try keychain.setDriveIdentifiers(allDrives, for: accountUID)
		didUpdatePublisher.send(())
	}

	public func removeDriveFromKeychain(with accountUID: String, driveIdentifier: String) throws {
		var allDrives = try getDrivesFromKeychain(for: accountUID)
		allDrives.removeAll { $0.identifier == driveIdentifier }
		try keychain.setDriveIdentifiers(allDrives, for: accountUID)
		didUpdatePublisher.send(())
	}

	public func getDriveFromKeychain(for accountUID: String, driveID: String) throws -> MicrosoftGraphDrive? {
		let allDrives = try getDrivesFromKeychain(for: accountUID)
		return allDrives.first(where: { $0.identifier == driveID })
	}
}

extension CryptomatorKeychainType {
	func getDriveIdentifiers(for accountUID: String) throws -> [MicrosoftGraphDrive]? {
		let driveKey = "driveIdentifiers_\(accountUID)"
		guard let data = getAsData(driveKey) else {
			return nil
		}
		do {
			let jsonDecoder = JSONDecoder()
			let drives = try jsonDecoder.decode([MicrosoftGraphDrive].self, from: data)
			return drives
		} catch {
			return nil
		}
	}

	func setDriveIdentifiers(_ drives: [MicrosoftGraphDrive], for accountUID: String) throws {
		let driveKey = "driveIdentifiers_\(accountUID)"
		let jsonEncoder = JSONEncoder()
		let encodedDrives = try jsonEncoder.encode(drives)
		try set(driveKey, value: encodedDrives)
	}

	func getDrive(by driveID: String, for accountUID: String) throws -> MicrosoftGraphDrive? {
		let allDrives = try getDriveIdentifiers(for: accountUID) ?? []
		return allDrives.first(where: { $0.identifier == driveID })
	}
}
