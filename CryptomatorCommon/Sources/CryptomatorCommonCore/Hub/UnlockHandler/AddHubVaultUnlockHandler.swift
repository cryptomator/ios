import Foundation

public struct AddHubVaultUnlockHandler: HubVaultUnlockHandler {
	private let vaultUID: String
	private let accountUID: String
	private let vaultItem: VaultItem
	private let downloadedVaultConfig: DownloadedVaultConfig
	private let vaultManager: VaultManager
	private weak var delegate: HubVaultUnlockHandlerDelegate?

	public init(vaultUID: String,
	            accountUID: String,
	            vaultItem: VaultItem,
	            downloadedVaultConfig: DownloadedVaultConfig,
	            vaultManager: VaultManager,
	            delegate: HubVaultUnlockHandlerDelegate?) {
		self.vaultUID = vaultUID
		self.accountUID = accountUID
		self.vaultItem = vaultItem
		self.downloadedVaultConfig = downloadedVaultConfig
		self.vaultManager = vaultManager
		self.delegate = delegate
	}

	public func didSuccessfullyRemoteUnlock(_ response: HubUnlockResponse) async {
		let jwe = response.jwe
		let privateKey = response.privateKey
		let hubVault = ExistingHubVault(vaultUID: vaultUID,
		                                delegateAccountUID: accountUID,
		                                jweData: jwe.compactSerializedData,
		                                privateKey: privateKey,
		                                vaultItem: vaultItem,
		                                downloadedVaultConfig: downloadedVaultConfig)
		do {
			try await vaultManager.addExistingHubVault(hubVault).getValue()
			await delegate?.successfullyProcessedUnlockedVault()
		} catch {
			await delegate?.failedToProcessUnlockedVault(error: error)
		}
	}
}
