//
//  VaultDetailViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Dependencies
import GRDB
import LocalAuthentication
import Promises
import UIKit

protocol VaultDetailViewModelProtocol {
	var numberOfSections: Int { get }
	var vaultUID: String { get }
	var vaultName: String { get }
	var title: Bindable<String> { get }
	var actionPublisher: AnyPublisher<Result<VaultDetailButtonAction, Error>, Never> { get }

	func numberOfRows(in section: Int) -> Int
	func cellViewModel(for indexPath: IndexPath) -> BindableTableViewCellViewModel
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
	case showRenameVault
	case showMoveVault
	case showChangeVaultPassword
	case showKeepUnlockedScreen(currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration>)
}

private enum VaultDetailSection {
	case vaultInfoSection
	case lockingSection
	case removeVaultSection
	case moveVaultSection
	case changeVaultPasswordSection
}

class VaultDetailViewModel: VaultDetailViewModelProtocol {
	let title: Bindable<String>
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
	@Dependency(\.fileProviderConnector) private var fileProviderConnector
	private let context = LAContext()
	private let vaultKeepUnlockedSettings: VaultKeepUnlockedSettings
	private let passwordManager: VaultPasswordManager
	private var vaultPath: CloudPath {
		return vaultInfo.vaultPath
	}

	private var subscribers = Set<AnyCancellable>()

	private lazy var sections: [VaultDetailSection] = {
		if vaultIsEligibleToMove() {
			return [.vaultInfoSection, .lockingSection, .moveVaultSection, .changeVaultPasswordSection, .removeVaultSection]
		} else {
			return [.vaultInfoSection, .lockingSection, .changeVaultPasswordSection, .removeVaultSection]
		}
	}()

	private lazy var lockButton: ButtonCellViewModel<VaultDetailButtonAction> = {
		let viewModel = ButtonCellViewModel<VaultDetailButtonAction>(action: .lockVault, title: LocalizedString.getValue("vaultDetail.button.lock"), isEnabled: vaultInfo.vaultIsUnlocked.value)
		return viewModel
	}()

	private lazy var keepUnlockedCellViewModel = KeepUnlockedButtonCellViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration)

	private var cells: [VaultDetailSection: [BindableTableViewCellViewModel]] {
		return [
			.vaultInfoSection: [
				vaultInfoCellViewModel,
				ButtonCellViewModel<VaultDetailButtonAction>(action: .openVaultInFilesApp, title: LocalizedString.getValue("common.cells.openInFilesApp"))
			],
			.lockingSection: lockSectionCells,
			.moveVaultSection: vaultIsEligibleToMove() ? [
				renameVaultCellViewModel,
				moveVaultCellViewModel
			] : [],
			.changeVaultPasswordSection: [ButtonCellViewModel.createDisclosureButton(action: VaultDetailButtonAction.showChangeVaultPassword, title: LocalizedString.getValue("vaultDetail.button.changeVaultPassword"))],
			.removeVaultSection: [ButtonCellViewModel<VaultDetailButtonAction>(action: .removeVault, title: LocalizedString.getValue("vaultDetail.button.removeVault"), titleTextColor: .systemRed)]
		]
	}

	private var lockSectionCells: [BindableTableViewCellViewModel] {
		var cells: [BindableTableViewCellViewModel] = [lockButton, keepUnlockedCellViewModel]
		if let biometryTypeName = context.enrolledBiometricsAuthenticationName() {
			let switchCellViewModel = getSwitchCellViewModel(biometryTypeName: biometryTypeName)
			cells.append(switchCellViewModel)
		}
		return cells
	}

	private var switchCellViewModel: SwitchCellViewModel?

	private var biometricalUnlockSwitchSubscriber: AnyCancellable?

	private var biometricalUnlockEnabled: Bool {
		do {
			return try passwordManager.hasPassword(forVaultUID: vaultUID)
		} catch {
			DDLogError("biometricalUnlockEnabled failed with error: \(error)")
			return false
		}
	}

	private lazy var sectionFooter: [VaultDetailSection: HeaderFooterViewModel] = [.vaultInfoSection: VaultDetailInfoFooterViewModel(vault: vaultInfo),
	                                                                               .changeVaultPasswordSection: BaseHeaderFooterViewModel(title: LocalizedString.getValue("vaultDetail.changePassword.footer")),
	                                                                               .lockingSection: unlockSectionFooterViewModel,
	                                                                               .removeVaultSection: BaseHeaderFooterViewModel(title: LocalizedString.getValue("vaultDetail.removeVault.footer"))]

	private lazy var unlockSectionFooterViewModel = UnlockSectionFooterViewModel(vaultUnlocked: vaultInfo.vaultIsUnlocked.value, biometricalUnlockEnabled: biometricalUnlockEnabled, biometryTypeName: context.enrolledBiometricsAuthenticationName(), keepUnlockedDuration: currentKeepUnlockedDuration.value)

	private lazy var vaultInfoCellViewModel = BindableTableViewCellViewModel(title: vaultInfo.vaultName, detailTitle: vaultInfo.vaultPath.path, detailTitleTextColor: .secondaryLabel, image: UIImage(vaultIconFor: vaultInfo.cloudProviderType, state: .normal), selectionStyle: .none)
	private lazy var renameVaultCellViewModel = ButtonCellViewModel.createDisclosureButton(action: VaultDetailButtonAction.showRenameVault, title: LocalizedString.getValue("vaultDetail.button.renameVault"), detailTitle: vaultName)
	private lazy var moveVaultCellViewModel = ButtonCellViewModel.createDisclosureButton(action: VaultDetailButtonAction.showMoveVault, title: LocalizedString.getValue("vaultDetail.button.moveVault"), detailTitle: vaultPath.path)
	private lazy var currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration> = {
		let currentKeepUnlockedDuration = vaultKeepUnlockedSettings.getKeepUnlockedDuration(forVaultUID: vaultUID)
		return Bindable(currentKeepUnlockedDuration)
	}()

	private var observation: DatabaseCancellable?

	convenience init(vaultInfo: VaultInfo) {
		self.init(vaultInfo: vaultInfo, vaultManager: VaultDBManager.shared, passwordManager: VaultPasswordKeychainManager(), dbManager: DatabaseManager.shared, vaultKeepUnlockedSettings: VaultKeepUnlockedManager.shared)
	}

	init(vaultInfo: VaultInfo, vaultManager: VaultManager, passwordManager: VaultPasswordManager, dbManager: DatabaseManager, vaultKeepUnlockedSettings: VaultKeepUnlockedSettings) {
		self.vaultInfo = vaultInfo
		self.vaultManager = vaultManager
		self.passwordManager = passwordManager
		self.title = Bindable(vaultInfo.vaultName)
		self.vaultKeepUnlockedSettings = vaultKeepUnlockedSettings
		self.observation = dbManager.observeVaultAccount(withVaultUID: vaultInfo.vaultUID, onError: { error in
			DDLogError("Observe Vault Account error: \(error)")
		}, onChange: { [weak self] vaultAccount in
			guard let vaultAccount = vaultAccount else {
				return
			}
			self?.vaultInfo.vaultAccount = vaultAccount
			self?.title.value = vaultAccount.vaultName
			self?.updateViewModels()
		})
		setupBinding()
	}

	func numberOfRows(in section: Int) -> Int {
		let vaultDetailSection = sections[section]
		if let sectionCells = cells[vaultDetailSection] {
			return sectionCells.count
		} else {
			return 0
		}
	}

	func cellViewModel(for indexPath: IndexPath) -> BindableTableViewCellViewModel {
		let vaultDetailSection = sections[indexPath.section]
		guard let sectionCells = cells[vaultDetailSection] else {
			return BindableTableViewCellViewModel()
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
		_ = try vaultManager.removeVault(withUID: vaultUID)
	}

	func lockVault() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultUID)
		let getXPCPromise: Promise<XPC<VaultLocking>> = fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)

		return getXPCPromise.then { xpc -> Void in
			xpc.proxy.lockVault(domainIdentifier: domainIdentifier)
			self.vaultInfo.vaultIsUnlocked.value = false
		}
	}

	func refreshVaultStatus() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultUID)
		let getXPCPromise: Promise<XPC<VaultLocking>> = fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
		switchCellViewModel?.isOn.value = biometricalUnlockEnabled
		return getXPCPromise.then { xpc in
			return wrap { handler in
				xpc.proxy.getIsUnlockedVault(domainIdentifier: domainIdentifier, reply: handler)
			}
		}.then { isUnlocked -> Void in
			self.vaultInfo.vaultIsUnlocked.value = isUnlocked
		}
	}

	private func getSwitchCellViewModel(biometryTypeName: String) -> SwitchCellViewModel {
		if let switchCellViewModel = switchCellViewModel {
			switchCellViewModel.isOn.value = biometricalUnlockEnabled
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

	private func updateViewModels() {
		vaultInfoCellViewModel.title.value = vaultName
		renameVaultCellViewModel.detailTitle.value = vaultName
		moveVaultCellViewModel.detailTitle.value = vaultPath.path
	}

	private func vaultIsEligibleToMove() -> Bool {
		if case CloudProviderType.localFileSystem = vaultInfo.cloudProviderType {
			return false
		}
		return vaultInfo.vaultPath != CloudPath("/")
	}

	private func setupBinding() {
		bindUnlockSectionFooterViewModel()
		bindLockButton()
	}

	private func bindUnlockSectionFooterViewModel() {
		vaultInfo.vaultIsUnlocked.$value.assign(to: \.vaultUnlocked, on: unlockSectionFooterViewModel).store(in: &subscribers)
		switchCellViewModel?.isOn.$value.assign(to: \.biometricalUnlockEnabled, on: unlockSectionFooterViewModel).store(in: &subscribers)
		currentKeepUnlockedDuration.$value.assign(to: \.keepUnlockedDuration, on: unlockSectionFooterViewModel).store(in: &subscribers)
	}

	private func bindLockButton() {
		vaultInfo.vaultIsUnlocked.$value.assign(to: \.isEnabled.value, on: lockButton).store(in: &subscribers)
	}
}

private class KeepUnlockedButtonCellViewModel: ButtonCellViewModel<VaultDetailButtonAction> {
	private let currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration>
	private var subscriber: AnyCancellable?

	init(currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration>, isEnabled: Bool = true) {
		self.currentKeepUnlockedDuration = currentKeepUnlockedDuration
		let detailTitle = KeepUnlockedButtonCellViewModel.getDescription(forDuration: currentKeepUnlockedDuration.value)
		super.init(action: .showKeepUnlockedScreen(currentKeepUnlockedDuration: currentKeepUnlockedDuration), title: LocalizedString.getValue("vaultDetail.keepUnlocked.title"), titleTextColor: nil, detailTitle: detailTitle, isEnabled: isEnabled, accessoryType: .disclosureIndicator)
		setupBinding()
	}

	private func setupBinding() {
		subscriber = currentKeepUnlockedDuration.$value.sink { [weak self] currentKeepUnlockedDuration in
			self?.detailTitle.value = KeepUnlockedButtonCellViewModel.getDescription(forDuration: currentKeepUnlockedDuration)
		}
	}

	private static func getDescription(forDuration duration: KeepUnlockedDuration) -> String? {
		return duration.shortDisplayName
	}
}
