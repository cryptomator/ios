import CryptoKit
import Foundation

public struct ExistingHubVault {
	let vaultUID: String
	let delegateAccountUID: String
	let jweData: Data
	let privateKey: P384.KeyAgreement.PrivateKey
	let vaultItem: VaultItem
	let downloadedVaultConfig: DownloadedVaultConfig

	public init(vaultUID: String, delegateAccountUID: String, jweData: Data, privateKey: P384.KeyAgreement.PrivateKey, vaultItem: VaultItem, downloadedVaultConfig: DownloadedVaultConfig) {
		self.vaultUID = vaultUID
		self.delegateAccountUID = delegateAccountUID
		self.jweData = jweData
		self.privateKey = privateKey
		self.vaultItem = vaultItem
		self.downloadedVaultConfig = downloadedVaultConfig
	}
}
