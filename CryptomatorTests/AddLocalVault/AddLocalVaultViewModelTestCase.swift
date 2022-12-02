//
//  AddLocalVaultViewModelTestCase.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import XCTest
@testable import Cryptomator
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCryptoLib

class AddLocalVaultViewModelTestCase: XCTestCase {
	var tmpDirURL: URL!
	var accountManagerMock: CloudProviderAccountManagerMock!
	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: false)
		accountManagerMock = CloudProviderAccountManagerMock()
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func createVault(at url: URL) throws {
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let vaultConfig = VaultConfig(id: "ABB9F673-F3E8-41A7-A43B-D29F5DA65068", format: 8, cipherCombo: .sivCtrMac, shorteningThreshold: 220)
		let cryptor = Cryptor(masterkey: masterkey, scheme: .sivCtrMac)
		let rootDirPath = try getRootDirectoryURL(for: cryptor, vaultURL: url)
		try FileManager.default.createDirectory(at: rootDirPath, withIntermediateDirectories: true, attributes: nil)
		let masterkeyData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 999, passphrase: "password", scryptCostParam: 2)
		let masterkeyURL = url.appendingPathComponent("masterkey.cryptomator")
		try masterkeyData.write(to: masterkeyURL)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		let vaultConfigURL = url.appendingPathComponent("vault.cryptomator")
		try token.write(to: vaultConfigURL)
	}

	func createLegacyVault(at url: URL) throws {
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let cryptor = Cryptor(masterkey: masterkey, scheme: .sivCtrMac)
		let rootDirPath = try getRootDirectoryURL(for: cryptor, vaultURL: url)
		try FileManager.default.createDirectory(at: rootDirPath, withIntermediateDirectories: true, attributes: nil)
		let masterkeyData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 7, passphrase: "password", scryptCostParam: 2)
		let masterkeyURL = url.appendingPathComponent("masterkey.cryptomator")
		try masterkeyData.write(to: masterkeyURL)
	}

	private func getRootDirectoryURL(for cryptor: Cryptor, vaultURL: URL) throws -> URL {
		let digest = try cryptor.encryptDirId(Data())
		let i = digest.index(digest.startIndex, offsetBy: 2)
		return vaultURL.appendingPathComponent("d/\(digest[..<i])/\(digest[i...])")
	}

	class CloudProviderAccountManagerMock: CloudProviderAccountManager {
		var savedAccounts = [CloudProviderAccount]()
		func getCloudProviderType(for accountUID: String) throws -> CloudProviderType {
			throw MockError.notMocked
		}

		func getAllAccountUIDs(for type: CloudProviderType) throws -> [String] {
			throw MockError.notMocked
		}

		func saveNewAccount(_ account: CloudProviderAccount) throws {
			savedAccounts.append(account)
		}

		func removeAccount(with accountUID: String) throws {
			throw MockError.notMocked
		}
	}
}

extension LocalFileSystemCredential: Equatable {
	public static func == (lhs: LocalFileSystemCredential, rhs: LocalFileSystemCredential) -> Bool {
		lhs.identifier == rhs.identifier && lhs.rootURL == rhs.rootURL
	}
}
