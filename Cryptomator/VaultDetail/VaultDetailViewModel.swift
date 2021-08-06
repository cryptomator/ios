//
//  VaultDetailViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCommonCore
import LocalAuthentication
import Promises
import UIKit

protocol VaultDetailViewModelProtocol {
	var numberOfSections: Int { get }
	var vaultUID: String { get }
	var vaultName: String { get }
	var actionPublisher: AnyPublisher<Result<VaultDetailButtonAction, Error>, Never> { get }

	func numberOfRows(in section: Int) -> Int
	func cellViewModel(for indexPath: IndexPath) -> TableViewCellViewModel
	func footerViewModel(for section: Int) -> HeaderFooterViewModel?
	func didSelectRow(at indexPath: IndexPath)

	func removeVault() throws
	func lockVault() -> Promise<Void>
	func refreshVaultStatus() -> Promise<Void>
}

enum VaultDetailButtonAction {
	case openVaultInFilesApp
	case lockVault
	case removeVault
	case showUnlockScreen(vault: VaultInfo, biometryTypeName: String)
}

private enum VaultDetailSection {
	case vaultInfoSection
	case lockingSection
	case removeVaultSection
}

class VaultDetailViewModel: VaultDetailViewModelProtocol {
	var numberOfSections: Int {
		return sections.count
	}

	var vaultUID: String {
		return vaultInfo.vaultUID
	}

	var vaultName: String {
		return vaultInfo.vaultName
	}

	var actionPublisher: AnyPublisher<Result<VaultDetailButtonAction, Error>, Never> {
		return _actionPublisher.eraseToAnyPublisher()
	}

	private let _actionPublisher = PassthroughSubject<Result<VaultDetailButtonAction, Error>, Never>()

	private let vaultInfo: VaultInfo
	private let vaultManager: VaultManager
	private let fileProviderConnector: FileProviderConnector
	private let context = LAContext()
	private let passwordManager: VaultPasswordManager

	private var subscribers = Set<AnyCancellable>()

	private let sections: [VaultDetailSection] = [.vaultInfoSection, .lockingSection, .removeVaultSection]
	private let lockButton = ButtonCellViewModel<VaultDetailButtonAction>(action: .lockVault, title: NSLocalizedString("vaultDetail.button.lock", comment: ""), isEnabled: false)
	private var cells: [VaultDetailSection: [TableViewCellViewModel]] {
		return [
			.vaultInfoSection: [
				DefaultTableCellViewModel(title: vaultInfo.vaultName, detailTitle: vaultInfo.vaultPath.path, detailTitleTextColor: .secondaryLabel, image: UIImage(vaultIconFor: vaultInfo.cloudProviderType, state: .normal)),
				ButtonCellViewModel<VaultDetailButtonAction>(action: .openVaultInFilesApp, title: NSLocalizedString("addVault.success.openFilesApp", comment: ""))
			],
			.lockingSection: lockSectionCells,
			.removeVaultSection: [ButtonCellViewModel<VaultDetailButtonAction>(action: .removeVault, title: NSLocalizedString("vaultDetail.button.removeVault", comment: ""), titleTextColor: .systemRed)]
		]
	}

	private var lockSectionCells: [TableViewCellViewModel] {
		if canEvaluatePolicy, let biometryTypeName = getName(for: context.biometryType) {
			let switchCellViewModel = getSwitchCellViewModel(biometryTypeName: biometryTypeName)
			return [
				lockButton,
				switchCellViewModel
			]
		} else {
			return [lockButton]
		}
	}

	private var switchCellViewModel: SwitchCellViewModel?

	private var biometricalUnlockSwitchSubscriber: AnyCancellable?

	private var biometricalUnlockEnabled: Bool {
		do {
			return try passwordManager.hasPassword(forVaultUID: vaultUID)
		} catch {
			DDLogError("VaultDetailViewModel - biometricalUnlockEnabled failed with error: \(error)")
			return false
		}
	}

	private lazy var canEvaluatePolicy: Bool = {
		var error: NSError?
		if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
			return true
		} else {
			DDLogError("VaultDetailViewModel - Can not evaluate policy due to error: \(error?.description ?? "")")
			return false
		}
	}()

	private lazy var sectionFooter: [VaultDetailSection: HeaderFooterViewModel] = {
		[.vaultInfoSection: VaultDetailInfoFooterViewModel(vault: vaultInfo),
		 .lockingSection: unlockSectionFooterViewModel,
		 .removeVaultSection: BaseHeaderFooterViewModel(title: NSLocalizedString("vaultDetail.removeVault.footer", comment: ""))]
	}()

	private lazy var unlockSectionFooterViewModel: UnlockSectionFooterViewModel = {
		let viewModel = UnlockSectionFooterViewModel(vaultUnlocked: vaultInfo.vaultIsUnlocked, biometricalUnlockEnabled: biometricalUnlockEnabled, biometryTypeName: getName(for: context.biometryType))

		// Binding
		lockButton.isEnabled.$value.assign(to: \.vaultUnlocked, on: viewModel).store(in: &subscribers)
		switchCellViewModel?.$isOn.assign(to: \.biometricalUnlockEnabled, on: viewModel).store(in: &subscribers)

		return viewModel
	}()

	init(vaultInfo: VaultInfo, vaultManager: VaultManager = VaultDBManager.shared, fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared, passwordManager: VaultPasswordManager = VaultPasswordKeychainManager()) {
		self.vaultInfo = vaultInfo
		self.vaultManager = vaultManager
		self.fileProviderConnector = fileProviderConnector
		self.passwordManager = passwordManager
	}

	func numberOfRows(in section: Int) -> Int {
		let vaultDetailSection = sections[section]
		if let sectionCells = cells[vaultDetailSection] {
			return sectionCells.count
		} else {
			return 0
		}
	}

	func cellViewModel(for indexPath: IndexPath) -> TableViewCellViewModel {
		let vaultDetailSection = sections[indexPath.section]
		guard let sectionCells = cells[vaultDetailSection] else {
			return DefaultTableCellViewModel()
		}
		return sectionCells[indexPath.row]
	}

	func footerViewModel(for section: Int) -> HeaderFooterViewModel? {
		let vaultDetailSection = sections[section]
		return sectionFooter[vaultDetailSection]
	}

	func didSelectRow(at indexPath: IndexPath) {
		let vaultDetailSection = sections[indexPath.section]
		guard let sectionCells = cells[vaultDetailSection], let buttonCell = sectionCells[indexPath.row] as? ButtonCellViewModel<VaultDetailButtonAction> else {
			return
		}
		_actionPublisher.send(.success(buttonCell.action))
	}

	func removeVault() throws {
		try vaultManager.removeVault(withUID: vaultUID).catch { error in
			DDLogError("VaultDetailViewModel: remove vault failed with error: \(error)")
		}
	}

	func lockVault() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultUID)
		let getProxyPromise: Promise<VaultLocking> = fileProviderConnector.getProxy(serviceName: VaultLockingService.name, domainIdentifier: domainIdentifier)
		return getProxyPromise.then { proxy -> Void in
			proxy.lockVault(domainIdentifier: domainIdentifier)
			self.vaultInfo.vaultIsUnlocked = false
			self.lockButton.isEnabled.value = false
		}
	}

	func refreshVaultStatus() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultUID)
		let getProxyPromise: Promise<VaultLocking> = fileProviderConnector.getProxy(serviceName: VaultLockingService.name, domainIdentifier: domainIdentifier)
		switchCellViewModel?.isOn = biometricalUnlockEnabled
		return getProxyPromise.then { proxy in
			return wrap { handler in
				proxy.getIsUnlockedVault(domainIdentifier: domainIdentifier, reply: handler)
			}
		}.then { isUnlocked -> Void in
			self.vaultInfo.vaultIsUnlocked = isUnlocked
			self.lockButton.isEnabled.value = isUnlocked
		}
	}

	private func getName(for biometryType: LABiometryType) -> String? {
		switch biometryType {
		case .faceID:
			return "Face ID"
		case .touchID:
			return "Touch ID"
		default:
			return nil
		}
	}

	private func getSwitchCellViewModel(biometryTypeName: String) -> SwitchCellViewModel {
		if let switchCellViewModel = self.switchCellViewModel {
			switchCellViewModel.isOn = biometricalUnlockEnabled
			return switchCellViewModel
		}
		let viewModel = SwitchCellViewModel(title: biometryTypeName, titleTextColor: nil, isOn: biometricalUnlockEnabled)
		switchCellViewModel = viewModel
		biometricalUnlockSwitchSubscriber = viewModel.isOnButtonPublisher.sink(receiveValue: { [weak self] isOn in
			if isOn {
				// show unlock Screen
				guard let self = self else { return }
				self._actionPublisher.send(.success(.showUnlockScreen(vault: self.vaultInfo, biometryTypeName: biometryTypeName)))
			} else {
				// remove Password
				guard let self = self else { return }
				do {
					try self.passwordManager.removePassword(forVaultUID: self.vaultUID)
				} catch {
					self._actionPublisher.send(.failure(error))
				}
			}
		})
		return viewModel
	}
}
