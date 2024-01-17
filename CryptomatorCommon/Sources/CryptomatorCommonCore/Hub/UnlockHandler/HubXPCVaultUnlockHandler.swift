import CryptomatorCryptoLib
import Dependencies
import FileProvider

struct HubXPCVaultUnlockHandler: HubVaultUnlockHandler {
	private let fileProviderConnector: FileProviderConnector
	private let domain: NSFileProviderDomain
	private weak var delegate: HubVaultUnlockHandlerDelegate?
	@Dependency(\.hubRepository) private var hubRepository

	init(fileProviderConnector: FileProviderConnector,
	     domain: NSFileProviderDomain,
	     delegate: HubVaultUnlockHandlerDelegate) {
		self.fileProviderConnector = fileProviderConnector
		self.domain = domain
		self.delegate = delegate
	}

	func didSuccessfullyRemoteUnlock(_ response: HubUnlockResponse) async {
		let masterkey: Masterkey
		do {
			masterkey = try JWEHelper.decryptVaultKey(jwe: response.jwe, with: response.privateKey)
		} catch {
			await delegate?.failedToProcessUnlockedVault(error: error)
			return
		}
		do {
			let xpc: XPC<VaultUnlocking> = try await fileProviderConnector.getXPC(serviceName: .vaultUnlocking, domain: domain)
			defer {
				fileProviderConnector.invalidateXPC(xpc)
			}
			try await xpc.proxy.unlockVault(rawKey: masterkey.rawKey).getValue()
			let hubVault = HubVault(vaultUID: domain.identifier.rawValue, subscriptionState: response.subscriptionState)
			try hubRepository.save(hubVault)
			await delegate?.successfullyProcessedUnlockedVault()
		} catch {
			await delegate?.failedToProcessUnlockedVault(error: error)
			return
		}
	}
}
