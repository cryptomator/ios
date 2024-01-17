//
//  AddHubVaultUnlockHandlerTests.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 19.11.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.

import JOSESwift
import Promises
import XCTest
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore
@testable import CryptomatorCryptoLib

final class AddHubVaultUnlockHandlerTests: XCTestCase {
	private let vaultUID = "vault-123456789"
	private let accountUID = "account-123456789"
	private var vaultManagerMock: VaultManagerMock!
	private var unlockHandlerDelegateMock: HubVaultUnlockHandlerDelegateMock!

	override func setUpWithError() throws {
		vaultManagerMock = VaultManagerMock()
		unlockHandlerDelegateMock = HubVaultUnlockHandlerDelegateMock()
	}

	func testDidSuccessfullyRemoteUnlock() async throws {
		let vaultConfig = VaultConfig(id: "ABB9F673-F3E8-41A7-A43B-D29F5DA65068", format: 8, cipherCombo: .sivCtrMac, shorteningThreshold: 220)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))

		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		let unverifiedVaultConfig = try UnverifiedVaultConfig(token: token)
		let metadata = CloudItemMetadata(name: "masterkey.cryptomator",
		                                 cloudPath: .init("/masterkey.cryptomator"),
		                                 itemType: .file,
		                                 lastModifiedDate: nil,
		                                 size: nil)
		let jwe = try JWE(compactSerialization: "eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJjcnYiOiJQLTM4NCIsImV4dCI6dHJ1ZSwia2V5X29wcyI6W10sImt0eSI6IkVDIiwieCI6Im9DLWlIcDhjZzVsUy1Qd3JjRjZxS0NzbWxfMFJzaEtCV0JJTUYzVjhuTGg2NGlCWTdsX0VsZ3Fjd0JZLXNsR3IiLCJ5IjoiVWozVzdYYVBQakJiMFRwWUFHeXlweVRIR3ByQU1hRXdWTk5Gb05tNEJuNjZuVkNKLU9pUUJYN3RhaVUtby1yWSJ9LCJhcHUiOiIiLCJhcHYiOiIifQ.._r7LC8HLc00jk2SI.ooeI0-E29jryMJ_wbGWKVc_IfHOh3Mlfh5geRYEmLTA4GKHItRYmDdZvGsCj9pJRoNORyHdmlAMxXXIXq_v9ZocoCwZrN7EsaB8A3Kukka35i1sr7kpNbksk3G_COsGRmwQ.GJCKBE-OZ7Nm5RMf_9UwVg")

		let privateKeyPemRepresentation = "-----BEGIN PRIVATE KEY-----\nMIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDDqcfr7I2SUcaYK/QHn\njhDGMpoAI1VBqzlGQ+QENqkwmGsk7N/mIQ3IJp5o7avKNJehZANiAASbOrmxoDPp\nb4AuVnUCyE1nw9KzDluGH8rozjUrteMS8ntzNlzK218iJgpRi6I3rLs8IoWTHrGE\nkfgDMgV4fk+7OC8AlKdofJudF/YcBsC00bhQ2lhlEP+PtcpgkkcJbAI=\n-----END PRIVATE KEY-----"

		let downloadedVaultConfig = DownloadedVaultConfig(vaultConfig: unverifiedVaultConfig,
		                                                  token: token,
		                                                  metadata: metadata)
		let unlockHandler = AddHubVaultUnlockHandler(vaultUID: vaultUID,
		                                             accountUID: accountUID, vaultItem: VaultItemStub(), downloadedVaultConfig: downloadedVaultConfig,
		                                             vaultManager: vaultManagerMock,
		                                             delegate: unlockHandlerDelegateMock)
		vaultManagerMock.addExistingHubVaultReturnValue = Promise(())

		// WHEN
		// calling didSuccessfullyRemoteUnlock
		try await unlockHandler.didSuccessfullyRemoteUnlock(.init(jwe: jwe, privateKey: .init(pemRepresentation: privateKeyPemRepresentation), subscriptionState: .active))

		// THEN
		// the hub vault has been added as an existing one
		let savedHubVault = vaultManagerMock.addExistingHubVaultReceivedVault
		XCTAssertEqual(savedHubVault?.vaultUID, vaultUID)
		XCTAssertEqual(savedHubVault?.delegateAccountUID, accountUID)
		XCTAssertEqual(savedHubVault?.jweData, jwe.compactSerializedData)
		XCTAssertEqual(savedHubVault?.downloadedVaultConfig.token, token)

		// and the delegate gets informed that the handler successfully processed the unlocked vault
		XCTAssertEqual(unlockHandlerDelegateMock.successfullyProcessedUnlockedVaultCallsCount, 1)
		XCTAssertFalse(unlockHandlerDelegateMock.failedToProcessUnlockedVaultErrorCalled)
	}

	func testDidSuccessfullyRemoteUnlock_fails_informsDelegateAboutFailure() async throws {
		let vaultConfig = VaultConfig(id: "ABB9F673-F3E8-41A7-A43B-D29F5DA65068", format: 8, cipherCombo: .sivCtrMac, shorteningThreshold: 220)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))

		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		let unverifiedVaultConfig = try UnverifiedVaultConfig(token: token)
		let metadata = CloudItemMetadata(name: "masterkey.cryptomator",
		                                 cloudPath: .init("/masterkey.cryptomator"),
		                                 itemType: .file,
		                                 lastModifiedDate: nil,
		                                 size: nil)
		let jwe = try JWE(compactSerialization: "eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJjcnYiOiJQLTM4NCIsImV4dCI6dHJ1ZSwia2V5X29wcyI6W10sImt0eSI6IkVDIiwieCI6Im9DLWlIcDhjZzVsUy1Qd3JjRjZxS0NzbWxfMFJzaEtCV0JJTUYzVjhuTGg2NGlCWTdsX0VsZ3Fjd0JZLXNsR3IiLCJ5IjoiVWozVzdYYVBQakJiMFRwWUFHeXlweVRIR3ByQU1hRXdWTk5Gb05tNEJuNjZuVkNKLU9pUUJYN3RhaVUtby1yWSJ9LCJhcHUiOiIiLCJhcHYiOiIifQ.._r7LC8HLc00jk2SI.ooeI0-E29jryMJ_wbGWKVc_IfHOh3Mlfh5geRYEmLTA4GKHItRYmDdZvGsCj9pJRoNORyHdmlAMxXXIXq_v9ZocoCwZrN7EsaB8A3Kukka35i1sr7kpNbksk3G_COsGRmwQ.GJCKBE-OZ7Nm5RMf_9UwVg")

		let privateKeyPemRepresentation = "-----BEGIN PRIVATE KEY-----\nMIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDDqcfr7I2SUcaYK/QHn\njhDGMpoAI1VBqzlGQ+QENqkwmGsk7N/mIQ3IJp5o7avKNJehZANiAASbOrmxoDPp\nb4AuVnUCyE1nw9KzDluGH8rozjUrteMS8ntzNlzK218iJgpRi6I3rLs8IoWTHrGE\nkfgDMgV4fk+7OC8AlKdofJudF/YcBsC00bhQ2lhlEP+PtcpgkkcJbAI=\n-----END PRIVATE KEY-----"

		let downloadedVaultConfig = DownloadedVaultConfig(vaultConfig: unverifiedVaultConfig,
		                                                  token: token,
		                                                  metadata: metadata)
		let unlockHandler = AddHubVaultUnlockHandler(vaultUID: vaultUID,
		                                             accountUID: accountUID, vaultItem: VaultItemStub(), downloadedVaultConfig: downloadedVaultConfig,
		                                             vaultManager: vaultManagerMock,
		                                             delegate: unlockHandlerDelegateMock)
		// GIVEN
		// the existing hub vault can't be added due to an error
		vaultManagerMock.addExistingHubVaultReturnValue = Promise(TestError())

		// WHEN
		// calling didSuccessfullyRemoteUnlock
		try await unlockHandler.didSuccessfullyRemoteUnlock(.init(jwe: jwe, privateKey: .init(pemRepresentation: privateKeyPemRepresentation), subscriptionState: .active))

		// THEN
		// the delegate gets informed that the handler failed to process the unlocked vault
		XCTAssertEqual(unlockHandlerDelegateMock.failedToProcessUnlockedVaultErrorCallsCount, 1)
		XCTAssert(unlockHandlerDelegateMock.failedToProcessUnlockedVaultErrorReceivedError is TestError)
		XCTAssertFalse(unlockHandlerDelegateMock.successfullyProcessedUnlockedVaultCalled)
	}

	private struct VaultItemStub: VaultItem {
		let name = "name"
		let vaultPath = CloudPath("/name")
	}

	private struct TestError: Error {}
}
