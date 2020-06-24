//
//  VaultFormat7LocalFileSystemProviderIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 23.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//
import CloudAccessPrivate
import XCTest
@testable import CryptomatorCloudAccess
@testable import CryptomatorCryptoLib
@testable import Promises
class VaultFormat7LocalFileSystemCloudProviderIntegrationTests: IntegrationTestWithAuthentication {
	static var setUpErrorForVaultFormat7LocalFileSystem: Error?
	override class var classSetUpError: Error? {
		get {
			return setUpErrorForVaultFormat7LocalFileSystem
		}
		set {
			setUpErrorForVaultFormat7LocalFileSystem = newValue
		}
	}

	static let setUpAuthenticationForLocalFileSystem = MockLocalFileSystemAuthentication()

	private static let cloudProvider = LocalFileSystemProvider()
	private static let vaultURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
	private static let cryptor = Cryptor(masterkey: Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32), version: 7))

	static let setUpProviderForVaultFormat7LocalFileSystem: VaultFormat7ShorteningProviderDecorator? = {
		let cloudProvider = LocalFileSystemProvider()
		do {
			let crptorDecorator = try VaultFormat7ProviderDecorator(delegate: cloudProvider, vaultURL: vaultURL, cryptor: cryptor)
			let provider = try VaultFormat7ShorteningProviderDecorator(delegate: crptorDecorator, vaultURL: vaultURL)
			return provider
		} catch {
			return nil
		}
	}()

	override class var setUpAuthentication: MockCloudAuthentication {
		return setUpAuthenticationForLocalFileSystem
	}

	override class var setUpProvider: CloudProvider? {
		return setUpProviderForVaultFormat7LocalFileSystem
	}

	static let remoteRootURLForIntegrationTestAtVaultFormat7LocalFileSystem = URL(fileURLWithPath: "/", isDirectory: true)
	override class var remoteRootURLForIntegrationTest: URL {
		return remoteRootURLForIntegrationTestAtVaultFormat7LocalFileSystem
	}

	override class func setUp() {
		// TODO: SetUp Vault
		super.setUp()
	}

	override func setUpWithError() throws {
		try super.setUpWithError()
		let auth = MockLocalFileSystemAuthentication()
		super.authentication = auth
		let cloudProvider = LocalFileSystemProvider()
		let crptorDecorator = try VaultFormat7ProviderDecorator(delegate: cloudProvider, vaultURL: VaultFormat7LocalFileSystemCloudProviderIntegrationTests.vaultURL, cryptor: VaultFormat7LocalFileSystemCloudProviderIntegrationTests.cryptor)
		let provider = try VaultFormat7ShorteningProviderDecorator(delegate: crptorDecorator, vaultURL: VaultFormat7LocalFileSystemCloudProviderIntegrationTests.vaultURL)
		super.provider = provider
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: VaultFormat7LocalFileSystemCloudProviderIntegrationTests.self)
	}
}
