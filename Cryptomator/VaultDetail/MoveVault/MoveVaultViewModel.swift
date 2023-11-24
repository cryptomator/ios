//
//  MoveVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 22.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Dependencies
import FileProvider
import Foundation
import GRDB
import Promises

protocol MoveVaultViewModelProtocol: ChooseFolderViewModelProtocol {
	func moveVault() async throws
	func isAllowedToMove() -> Bool
}

enum MoveVaultViewModelError: Error {
	case moveVaultInsideItselfNotAllowed
	case vaultNotEligibleForMove
}

class MoveVaultViewModel: ChooseFolderViewModel, MoveVaultViewModelProtocol {
	private let vaultManager: VaultManager
	private let vaultInfo: VaultInfo
	private let domain: NSFileProviderDomain
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	init(provider: CloudProvider,
	     currentFolderChoosingCloudPath: CloudPath,
	     vaultInfo: VaultInfo,
	     domain: NSFileProviderDomain,
	     cloudProviderManager: CloudProviderManager = CloudProviderDBManager.shared,
	     vaultManager: VaultManager = VaultDBManager.shared) {
		self.vaultInfo = vaultInfo
		self.domain = domain
		self.vaultManager = vaultManager
		super.init(canCreateFolder: true, cloudPath: currentFolderChoosingCloudPath, provider: provider)
	}

	func moveVault(to targetCloudPath: CloudPath) async throws {
		guard vaultEligibleForMove() else {
			throw MoveVaultViewModelError.vaultNotEligibleForMove
		}
		guard pathIsNotInsideCurrentVaultPath(targetCloudPath) else {
			throw MoveVaultViewModelError.moveVaultInsideItselfNotAllowed
		}
		let xpc: XPC<MaintenanceModeHelper> = try await fileProviderConnector.getXPC(serviceName: .maintenanceModeHelper,
		                                                                             domain: domain)
		defer {
			fileProviderConnector.invalidateXPC(xpc)
		}
		try await xpc.proxy.executeExclusiveOperation {
			try await self.lockVault()
			try await self.moveVault(account: self.vaultInfo.vaultAccount, to: targetCloudPath)
		}
	}

	func moveVault() async throws {
		let newVaultPath = super.cloudPath.appendingPathComponent(vaultInfo.vaultName)
		try await moveVault(to: newVaultPath)
	}

	func isAllowedToMove() -> Bool {
		return cloudPath.appendingPathComponent(vaultInfo.vaultName) != vaultInfo.vaultPath
	}

	private func lockVault() async throws {
		let xpc: XPC<VaultLocking> = try await fileProviderConnector.getXPC(serviceName: .vaultLocking,
		                                                                    domain: domain)
		xpc.proxy.lockVault(domainIdentifier: domain.identifier)
		fileProviderConnector.invalidateXPC(xpc)
	}

	private func vaultEligibleForMove() -> Bool {
		if vaultInfo.vaultPath == CloudPath("/") {
			return false
		}
		if case CloudProviderType.localFileSystem = vaultInfo.cloudProviderType {
			return false
		}
		return true
	}

	private func pathIsNotInsideCurrentVaultPath(_ path: CloudPath) -> Bool {
		return !path.contains(vaultInfo.vaultPath)
	}

	private func moveVault(account: VaultAccount, to targetVaultPath: CloudPath) async throws {
		try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
			vaultManager.moveVault(account: account, to: targetVaultPath).then {
				continuation.resume()
			}.catch {
				continuation.resume(throwing: $0)
			}
		})
	}
}
