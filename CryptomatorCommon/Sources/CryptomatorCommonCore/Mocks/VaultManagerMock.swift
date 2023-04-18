//
//  VaultManagerMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 27.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import Foundation
import Promises

// swiftlint: disable all

final class VaultManagerMock: VaultManager {
	// MARK: - createNewVault

	var createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainThrowableError: Error?
	var createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainCallsCount = 0
	var createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainCalled: Bool {
		createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainCallsCount > 0
	}

	var createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainReceivedArguments: (vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool)?
	var createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainReceivedInvocations: [(vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool)] = []
	var createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainReturnValue: Promise<Void>!
	var createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainClosure: ((String, String, CloudPath, String, Bool) -> Promise<Void>)?

	func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		if let error = createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainThrowableError {
			return Promise(error)
		}
		createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainCallsCount += 1
		createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainReceivedArguments = (vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, password: password, storePasswordInKeychain: storePasswordInKeychain)
		createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainReceivedInvocations.append((vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, password: password, storePasswordInKeychain: storePasswordInKeychain))
		return createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainClosure.map({ $0(vaultUID, delegateAccountUID, vaultPath, password, storePasswordInKeychain) }) ?? createNewVaultWithVaultUIDDelegateAccountUIDVaultPathPasswordStorePasswordInKeychainReturnValue
	}

	// MARK: - createFromExisting

	var createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainThrowableError: Error?
	var createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainCallsCount = 0
	var createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainCalled: Bool {
		createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainCallsCount > 0
	}

	var createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReceivedArguments: (vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool)?
	var createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReceivedInvocations: [(vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool)] = []
	var createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReturnValue: Promise<Void>!
	var createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainClosure: ((String, String, VaultItem, String, Bool) -> Promise<Void>)?

	func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		if let error = createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainThrowableError {
			return Promise(error)
		}
		createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainCallsCount += 1
		createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReceivedArguments = (vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: vaultItem, password: password, storePasswordInKeychain: storePasswordInKeychain)
		createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReceivedInvocations.append((vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: vaultItem, password: password, storePasswordInKeychain: storePasswordInKeychain))
		return createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainClosure.map({ $0(vaultUID, delegateAccountUID, vaultItem, password, storePasswordInKeychain) }) ?? createFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReturnValue
	}

	// MARK: - createLegacyFromExisting

	var createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainThrowableError: Error?
	var createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainCallsCount = 0
	var createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainCalled: Bool {
		createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainCallsCount > 0
	}

	var createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReceivedArguments: (vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool)?
	var createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReceivedInvocations: [(vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool)] = []
	var createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReturnValue: Promise<Void>!
	var createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainClosure: ((String, String, VaultItem, String, Bool) -> Promise<Void>)?

	func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		if let error = createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainThrowableError {
			return Promise(error)
		}
		createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainCallsCount += 1
		createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReceivedArguments = (vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: vaultItem, password: password, storePasswordInKeychain: storePasswordInKeychain)
		createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReceivedInvocations.append((vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: vaultItem, password: password, storePasswordInKeychain: storePasswordInKeychain))
		return createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainClosure.map({ $0(vaultUID, delegateAccountUID, vaultItem, password, storePasswordInKeychain) }) ?? createLegacyFromExistingWithVaultUIDDelegateAccountUIDVaultItemPasswordStorePasswordInKeychainReturnValue
	}

	// MARK: - manualUnlockVault

	var manualUnlockVaultWithUIDKekThrowableError: Error?
	var manualUnlockVaultWithUIDKekCallsCount = 0
	var manualUnlockVaultWithUIDKekCalled: Bool {
		manualUnlockVaultWithUIDKekCallsCount > 0
	}

	var manualUnlockVaultWithUIDKekReceivedArguments: (vaultUID: String, kek: [UInt8])?
	var manualUnlockVaultWithUIDKekReceivedInvocations: [(vaultUID: String, kek: [UInt8])] = []
	var manualUnlockVaultWithUIDKekReturnValue: CloudProvider!
	var manualUnlockVaultWithUIDKekClosure: ((String, [UInt8]) throws -> CloudProvider)?

	func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider {
		if let error = manualUnlockVaultWithUIDKekThrowableError {
			throw error
		}
		manualUnlockVaultWithUIDKekCallsCount += 1
		manualUnlockVaultWithUIDKekReceivedArguments = (vaultUID: vaultUID, kek: kek)
		manualUnlockVaultWithUIDKekReceivedInvocations.append((vaultUID: vaultUID, kek: kek))
		return try manualUnlockVaultWithUIDKekClosure.map({ try $0(vaultUID, kek) }) ?? manualUnlockVaultWithUIDKekReturnValue
	}

	// MARK: - createVaultProvider

	var createVaultProviderWithUIDMasterkeyThrowableError: Error?
	var createVaultProviderWithUIDMasterkeyCallsCount = 0
	var createVaultProviderWithUIDMasterkeyCalled: Bool {
		createVaultProviderWithUIDMasterkeyCallsCount > 0
	}

	var createVaultProviderWithUIDMasterkeyReceivedArguments: (vaultUID: String, masterkey: Masterkey)?
	var createVaultProviderWithUIDMasterkeyReceivedInvocations: [(vaultUID: String, masterkey: Masterkey)] = []
	var createVaultProviderWithUIDMasterkeyReturnValue: CloudProvider!
	var createVaultProviderWithUIDMasterkeyClosure: ((String, Masterkey) throws -> CloudProvider)?

	func createVaultProvider(withUID vaultUID: String, masterkey: Masterkey) throws -> CloudProvider {
		if let error = createVaultProviderWithUIDMasterkeyThrowableError {
			throw error
		}
		createVaultProviderWithUIDMasterkeyCallsCount += 1
		createVaultProviderWithUIDMasterkeyReceivedArguments = (vaultUID: vaultUID, masterkey: masterkey)
		createVaultProviderWithUIDMasterkeyReceivedInvocations.append((vaultUID: vaultUID, masterkey: masterkey))
		return try createVaultProviderWithUIDMasterkeyClosure.map({ try $0(vaultUID, masterkey) }) ?? createVaultProviderWithUIDMasterkeyReturnValue
	}

	// MARK: - removeVault

	var removeVaultWithUIDThrowableError: Error?
	var removeVaultWithUIDCallsCount = 0
	var removeVaultWithUIDCalled: Bool {
		removeVaultWithUIDCallsCount > 0
	}

	var removeVaultWithUIDReceivedVaultUID: String?
	var removeVaultWithUIDReceivedInvocations: [String] = []
	var removeVaultWithUIDReturnValue: Promise<Void>!
	var removeVaultWithUIDClosure: ((String) throws -> Promise<Void>)?

	func removeVault(withUID vaultUID: String) throws -> Promise<Void> {
		if let error = removeVaultWithUIDThrowableError {
			throw error
		}
		if let error = removeVaultWithUIDThrowableError {
			return Promise(error)
		}
		removeVaultWithUIDCallsCount += 1
		removeVaultWithUIDReceivedVaultUID = vaultUID
		removeVaultWithUIDReceivedInvocations.append(vaultUID)
		return try removeVaultWithUIDClosure.map({ try $0(vaultUID) }) ?? removeVaultWithUIDReturnValue
	}

	// MARK: - removeAllUnusedFileProviderDomains

	var removeAllUnusedFileProviderDomainsThrowableError: Error?
	var removeAllUnusedFileProviderDomainsCallsCount = 0
	var removeAllUnusedFileProviderDomainsCalled: Bool {
		removeAllUnusedFileProviderDomainsCallsCount > 0
	}

	var removeAllUnusedFileProviderDomainsReturnValue: Promise<Void>!
	var removeAllUnusedFileProviderDomainsClosure: (() -> Promise<Void>)?

	func removeAllUnusedFileProviderDomains() -> Promise<Void> {
		if let error = removeAllUnusedFileProviderDomainsThrowableError {
			return Promise(error)
		}
		removeAllUnusedFileProviderDomainsCallsCount += 1
		return removeAllUnusedFileProviderDomainsClosure.map({ $0() }) ?? removeAllUnusedFileProviderDomainsReturnValue
	}

	// MARK: - moveVault

	var moveVaultAccountToThrowableError: Error?
	var moveVaultAccountToCallsCount = 0
	var moveVaultAccountToCalled: Bool {
		moveVaultAccountToCallsCount > 0
	}

	var moveVaultAccountToReceivedArguments: (account: VaultAccount, targetVaultPath: CloudPath)?
	var moveVaultAccountToReceivedInvocations: [(account: VaultAccount, targetVaultPath: CloudPath)] = []
	var moveVaultAccountToReturnValue: Promise<Void>!
	var moveVaultAccountToClosure: ((VaultAccount, CloudPath) -> Promise<Void>)?

	func moveVault(account: VaultAccount, to targetVaultPath: CloudPath) -> Promise<Void> {
		if let error = moveVaultAccountToThrowableError {
			return Promise(error)
		}
		moveVaultAccountToCallsCount += 1
		moveVaultAccountToReceivedArguments = (account: account, targetVaultPath: targetVaultPath)
		moveVaultAccountToReceivedInvocations.append((account: account, targetVaultPath: targetVaultPath))
		return moveVaultAccountToClosure.map({ $0(account, targetVaultPath) }) ?? moveVaultAccountToReturnValue
	}

	// MARK: - changePassphrase

	var changePassphraseOldPassphraseNewPassphraseForVaultUIDThrowableError: Error?
	var changePassphraseOldPassphraseNewPassphraseForVaultUIDCallsCount = 0
	var changePassphraseOldPassphraseNewPassphraseForVaultUIDCalled: Bool {
		changePassphraseOldPassphraseNewPassphraseForVaultUIDCallsCount > 0
	}

	var changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments: (oldPassphrase: String, newPassphrase: String, vaultUID: String)?
	var changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedInvocations: [(oldPassphrase: String, newPassphrase: String, vaultUID: String)] = []
	var changePassphraseOldPassphraseNewPassphraseForVaultUIDReturnValue: Promise<Void>!
	var changePassphraseOldPassphraseNewPassphraseForVaultUIDClosure: ((String, String, String) -> Promise<Void>)?

	func changePassphrase(oldPassphrase: String, newPassphrase: String, forVaultUID vaultUID: String) -> Promise<Void> {
		if let error = changePassphraseOldPassphraseNewPassphraseForVaultUIDThrowableError {
			return Promise(error)
		}
		changePassphraseOldPassphraseNewPassphraseForVaultUIDCallsCount += 1
		changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedArguments = (oldPassphrase: oldPassphrase, newPassphrase: newPassphrase, vaultUID: vaultUID)
		changePassphraseOldPassphraseNewPassphraseForVaultUIDReceivedInvocations.append((oldPassphrase: oldPassphrase, newPassphrase: newPassphrase, vaultUID: vaultUID))
		return changePassphraseOldPassphraseNewPassphraseForVaultUIDClosure.map({ $0(oldPassphrase, newPassphrase, vaultUID) }) ?? changePassphraseOldPassphraseNewPassphraseForVaultUIDReturnValue
	}

	// MARK: - addExistingHubVault

	var addExistingHubVaultThrowableError: Error?
	var addExistingHubVaultCallsCount = 0
	var addExistingHubVaultCalled: Bool {
		addExistingHubVaultCallsCount > 0
	}

	var addExistingHubVaultReceivedVault: ExistingHubVault?
	var addExistingHubVaultReceivedInvocations: [ExistingHubVault] = []
	var addExistingHubVaultReturnValue: Promise<Void>!
	var addExistingHubVaultClosure: ((ExistingHubVault) -> Promise<Void>)?

	func addExistingHubVault(_ vault: ExistingHubVault) -> Promise<Void> {
		if let error = addExistingHubVaultThrowableError {
			return Promise(error)
		}
		addExistingHubVaultCallsCount += 1
		addExistingHubVaultReceivedVault = vault
		addExistingHubVaultReceivedInvocations.append(vault)
		return addExistingHubVaultClosure.map({ $0(vault) }) ?? addExistingHubVaultReturnValue
	}

	// MARK: - manualUnlockVault

	var manualUnlockVaultWithUIDRawKeyThrowableError: Error?
	var manualUnlockVaultWithUIDRawKeyCallsCount = 0
	var manualUnlockVaultWithUIDRawKeyCalled: Bool {
		manualUnlockVaultWithUIDRawKeyCallsCount > 0
	}

	var manualUnlockVaultWithUIDRawKeyReceivedArguments: (vaultUID: String, rawKey: [UInt8])?
	var manualUnlockVaultWithUIDRawKeyReceivedInvocations: [(vaultUID: String, rawKey: [UInt8])] = []
	var manualUnlockVaultWithUIDRawKeyReturnValue: CloudProvider!
	var manualUnlockVaultWithUIDRawKeyClosure: ((String, [UInt8]) throws -> CloudProvider)?

	func manualUnlockVault(withUID vaultUID: String, rawKey: [UInt8]) throws -> CloudProvider {
		if let error = manualUnlockVaultWithUIDRawKeyThrowableError {
			throw error
		}
		manualUnlockVaultWithUIDRawKeyCallsCount += 1
		manualUnlockVaultWithUIDRawKeyReceivedArguments = (vaultUID: vaultUID, rawKey: rawKey)
		manualUnlockVaultWithUIDRawKeyReceivedInvocations.append((vaultUID: vaultUID, rawKey: rawKey))
		return try manualUnlockVaultWithUIDRawKeyClosure.map({ try $0(vaultUID, rawKey) }) ?? manualUnlockVaultWithUIDRawKeyReturnValue
	}
}

// swiftlint: enable all
#endif
