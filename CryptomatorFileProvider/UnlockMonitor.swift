//
//  UnlockMonitor.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 31.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import Foundation
import LocalAuthentication

protocol UnlockMonitorType {
	/**
	 Executes the passed work item as soon as there is no running biometric unlock.

	 Every `enumerateItems(for:, startingAt:)` call should execute its work via this method.
	 */
	func execute(_ work: @escaping () -> Void)

	/**
	 Signals the start of a biometrical unlock for the vault with `vaultUID`.

	 This guarantees that from now on every work passed to `execute(_)` will not be executed until
	 the end of a biometrical unlock is signaled for the same vault via `endBiometricalUnlock(forVaultUID:)`.
	 */
	func startBiometricalUnlock(forVaultUID vaultUID: String)

	/**
	 Signals the end of a biometrical unlock for the vault with `vaultUID`.

	 This allows the work passed to `execute(_)` to be carried out.
	 Each call to `endBiometricalUnlock(forVaultUID:)` should be preceded by a call to `startBiometricalUnlock(forVaultUID)` for the same `vaultUID`.
	 If neither an `unlockFailed(forVaultUID:)` nor an `unlockSucceeded(forVaultUID:)` for the same `vaultUID`
	 preceded the call to `startBiometricalUnlock(forVaultUID)` and `endBiometricalUnlock(forVaultUID:)`,it is assumed
	 that the biometric unlock was canceled.
	 */
	func endBiometricalUnlock(forVaultUID vaultUID: String)

	/**
	 Signals that unlocking the vault with the `vaultUID` failed.

	 If the vault is in a biometric unlock state, i.e. there was a previous call to `startBiometricalUnlock(forVaultUID)`
	 and not yet a call to `endBiometricalUnlock(forVaultUID:)`, the password stored for the biometric unlock is incorrect for the vault and will therefore be removed.

	 Otherwise, the vault is in a manual unlock state and the current unlock state of the vault gets reseted.
	 */
	func unlockFailed(forVaultUID vaultUID: String)

	/**
	 Signals that unlocking the vault with the `vaultUID` succeeded.

	 This resets the current unlock state of the vault.
	 */
	func unlockSucceeded(forVaultUID vaultUID: String)

	/**
	 Returns the current `UnlockMonitorError` for the vault with `vaultUID` depending on its unlock state.

	 This is used to display various authentication errors in the Files app.
	 If the vault with the `vaultUID` is not currently in the unlock state "wrong biometric password" or "biometric unlock canceled", the default error `.defaultLock` will be returned.

	 The default error `.defaultLock` is also returned if the vault is currently in one of the two unlock states "wrong biometric password" or
	 "biometric unlock canceled" but the device is no longer enrolled for biometric authentication.
	 */
	func getUnlockError(forVaultUID vaultUID: String) -> UnlockMonitorError
}

class UnlockMonitor: UnlockMonitorType {
	var enrolledBiometricsAuthenticationName: () -> String? = { LAContext().enrolledBiometricsAuthenticationName() }
	private(set) lazy var unlockStates = [String: BiometricalUnlockState]()
	private let queue = DispatchQueue(label: "BiometricalUnlockMonitor", attributes: .concurrent)
	private let taskExecutor: UnlockMonitorTaskExecutorType
	private let vaultPasswordManager: VaultPasswordManager

	init(taskExecutor: UnlockMonitorTaskExecutorType = UnlockMonitorTaskExecutor(), vaultPasswordManager: VaultPasswordManager = VaultPasswordKeychainManager()) {
		self.taskExecutor = taskExecutor
		self.vaultPasswordManager = vaultPasswordManager
	}

	func startBiometricalUnlock(forVaultUID vaultUID: String) {
		queue.sync(flags: .barrier) {
			unlockStates[vaultUID] = .biometricalUnlockStarted
		}
		taskExecutor.runningBiometricalUnlock = true
	}

	func endBiometricalUnlock(forVaultUID vaultUID: String) {
		queue.sync(flags: .barrier) {
			switch unlockStates[vaultUID] {
			case .biometricalUnlockStarted:
				unlockStates[vaultUID] = .biometricalUnlockCanceled
			case .wrongPassword, .none:
				break
			default:
				DDLogDebug("Unexpected call to endBiometricalUnlock(forVaultUID:)")
			}
		}
		taskExecutor.runningBiometricalUnlock = false
	}

	func unlockFailed(forVaultUID vaultUID: String) {
		queue.sync(flags: .barrier) {
			switch unlockStates[vaultUID] {
			case .biometricalUnlockStarted:
				unlockStates[vaultUID] = .wrongPassword
				do {
					try vaultPasswordManager.removePassword(forVaultUID: vaultUID)
				} catch {
					DDLogError("Remove password for biometrical unlock failed with: \(error)")
				}
			case .biometricalUnlockCanceled, .wrongPassword, .none:
				unlockStates[vaultUID] = nil
			}
		}
	}

	func unlockSucceeded(forVaultUID vaultUID: String) {
		queue.sync(flags: .barrier) {
			unlockStates[vaultUID] = nil
		}
	}

	func getUnlockError(forVaultUID vaultUID: String) -> UnlockMonitorError {
		guard let biometryName = enrolledBiometricsAuthenticationName() else {
			return .defaultLock
		}
		return queue.sync {
			switch unlockStates[vaultUID] {
			case .wrongPassword:
				return .biometricalUnlockWrongPassword(biometryName: biometryName)
			case .biometricalUnlockCanceled:
				return .biometricalUnlockCanceled(biometryName: biometryName)
			default:
				return .defaultLock
			}
		}
	}

	func execute(_ work: @escaping () -> Void) {
		taskExecutor.execute {
			work()
		}
	}

	enum BiometricalUnlockState {
		case biometricalUnlockStarted
		case biometricalUnlockCanceled
		case wrongPassword
	}
}

protocol UnlockMonitorTaskExecutorType: AnyObject {
	var runningBiometricalUnlock: Bool { get set }
	func execute(_ work: @escaping () -> Void)
}

class UnlockMonitorTaskExecutor: UnlockMonitorTaskExecutorType {
	public var runningBiometricalUnlock: Bool = false {
		didSet {
			if runningBiometricalUnlock {
				lock.unlock(withCondition: UnlockMonitorTaskExecutor.RUNNING_BIOMETRICAL_UNLOCK)
			} else {
				lock.unlock(withCondition: UnlockMonitorTaskExecutor.NO_RUNNING_BIOMETRICAL_UNLOCK)
			}
		}
	}

	// swiftlint:disable identifier_name
	private static let RUNNING_BIOMETRICAL_UNLOCK = 1
	private static let NO_RUNNING_BIOMETRICAL_UNLOCK = 0
	// swiftlint:enable identifier_name
	private lazy var lock = NSConditionLock(condition: UnlockMonitorTaskExecutor.NO_RUNNING_BIOMETRICAL_UNLOCK)
	private let queue = DispatchQueue(label: "UnlockHelper")

	private func wait() {
		lock.lock(whenCondition: UnlockMonitorTaskExecutor.NO_RUNNING_BIOMETRICAL_UNLOCK)
		lock.unlock(withCondition: UnlockMonitorTaskExecutor.NO_RUNNING_BIOMETRICAL_UNLOCK)
	}

	public func execute(_ work: @escaping () -> Void) {
		queue.async { [weak self] in
			self?.wait()
			work()
		}
	}
}

public enum UnlockMonitorError: Error, LocalizedError, Equatable {
	case biometricalUnlockWrongPassword(biometryName: String)
	case biometricalUnlockCanceled(biometryName: String)
	case defaultLock

	public var errorDescription: String? {
		switch self {
		case .biometricalUnlockWrongPassword:
			return LocalizedString.getValue("fileProvider.error.biometricalAuthWrongPassword.title")
		case .biometricalUnlockCanceled:
			return LocalizedString.getValue("fileProvider.error.biometricalAuthCanceled.title")
		case .defaultLock:
			return LocalizedString.getValue("fileProvider.error.defaultLock.title")
		}
	}

	public var failureReason: String? {
		switch self {
		case let .biometricalUnlockWrongPassword(biometryName):
			return String(format: LocalizedString.getValue("fileProvider.error.biometricalAuthWrongPassword.message"), biometryName, biometryName)
		case let .biometricalUnlockCanceled(biometryName):
			return String(format: LocalizedString.getValue("fileProvider.error.biometricalAuthCanceled.message"), biometryName, biometryName)
		case .defaultLock:
			return LocalizedString.getValue("fileProvider.error.defaultLock.message")
		}
	}

	public var recoverySuggestion: String? {
		return LocalizedString.getValue("fileProvider.error.unlockButton")
	}

	/**
	 Returns the underlying error.

	 In order to use the error with the FileProviderExtensionUI, we need to export it to Objective-C.
	 As Objective-C does not support enums with associated values, we map the `UnlockMonitorError` to an `UnlockError`.
	 */
	public var underlyingError: UnlockError {
		switch self {
		case .biometricalUnlockWrongPassword:
			return .biometricalUnlockWrongPassword
		case .biometricalUnlockCanceled:
			return .biometricalUnlockCanceled
		case .defaultLock:
			return .defaultLock
		}
	}
}

@objc public enum UnlockError: Int, Error {
	case biometricalUnlockWrongPassword
	case biometricalUnlockCanceled
	case defaultLock
}
